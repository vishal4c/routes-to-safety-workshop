#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["duckdb==2.0.0"]
# ///
"""Precompute shelter coverage for the demo site (data/coverage/*.geojson).

  1. H3 hex grid (res 8, ~0.7 km² cells) over the study bbox, keeping cells that contain a drivable road.
  2. For every cell centroid, OSRM /table drive time to all shelters (batched ≤ --max-table-size 500).
  3. coverage_hex.geojson   = one hex per cell: nearest shelter by road + minutes + km
     coverage_bands.geojson = per shelter, dissolved 0–10 / 10–20 / 20–30-minute rings (non-overlapping)

Usage:  scripts/make-coverage.py [--osrm $OSRM_URL] [--res 8]        (--osrm defaults to $OSRM_URL, then http://localhost:8080/osrm)
This is Phase 2c (reach bands / isochrones) — the same /table call as 03-routing/exercises.md Stretch A, with more points, dissolved with DuckDB spatial.
"""
import argparse, json, os, re, sys, time, urllib.error, urllib.request
import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = dict(l.strip().split("=", 1) for l in open(f"{ROOT}/versions.env") if "=" in l and not l.startswith("#"))
ap = argparse.ArgumentParser(); ap.add_argument("--osrm", default=os.environ.get("OSRM_URL", "http://localhost:8080/osrm").rstrip("/"), help="OSRM base URL (default: $OSRM_URL)"); ap.add_argument("--res", type=int, default=8)
ap.add_argument("--radius", type=int, default=1500, help="max snapping distance (m) from hex centroid to a road")
a = ap.parse_args()
W, S, E, N = (float(ENV[k]) for k in ("BBOX_W", "BBOX_S", "BBOX_E", "BBOX_N"))
if not os.path.isfile(f"{ROOT}/data/overture/roads.geojson"):
    sys.exit("data/overture/roads.geojson missing — run Phase 1 · Fetch (scripts/fetch-overture.sh) · offline: scripts/stage-data.sh")
DRIVABLE = "('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street','motorway_link','trunk_link','primary_link','secondary_link','tertiary_link')"

con = duckdb.connect()
con.execute("INSTALL spatial; LOAD spatial; INSTALL h3 FROM community; LOAD h3; SET geometry_always_xy = true;")
t0 = time.time()
# 1. hex grid: polyfill the bbox, keep cells whose polygon intersects a drivable road
con.execute(f"""
CREATE TABLE cells AS
WITH ids AS (
  SELECT unnest(h3_polygon_wkt_to_cells_string(ST_AsText(ST_MakeEnvelope({W},{S},{E},{N})), {a.res})) AS h3
), hex AS (
  SELECT h3, ST_GeomFromText(h3_cell_to_boundary_wkt(h3)) AS geom,
         h3_cell_to_lng(h3) AS lon, h3_cell_to_lat(h3) AS lat FROM ids
)
SELECT h.* FROM hex h
WHERE EXISTS (SELECT 1 FROM ST_Read('{ROOT}/data/overture/roads.geojson') s
              WHERE s.class IN {DRIVABLE} AND ST_Intersects(h.geom, s.geom))
""")
cells = con.execute("SELECT h3, lon, lat FROM cells ORDER BY h3").fetchall()
shelters = json.load(open(f"{ROOT}/data/shelters.geojson"))["features"]
if not shelters:   # a Phase 4 pick that matched nothing → one placeholder shelter at the box's south-west corner (same as shelter_placeholder, scripts/lib.sh)
    shelters = [{"type": "Feature", "properties": {"id": "placeholder", "name": "Placeholder shelter (no shelter picked)", "status": "candidate", "type": "placeholder", "town": "",
                 "source": "placeholder at the south-west corner of the box in versions.env - no shelter picked yet; replace with real shelters (scripts/pick-shelters.sh)"},
                 "geometry": {"type": "Point", "coordinates": [W, S]}}]
    json.dump({"type": "FeatureCollection", "name": "shelters", "features": shelters}, open(f"{ROOT}/data/shelters.geojson", "w"))
    print(f"no shelters → data/shelters.geojson is one placeholder at the box's south-west corner ({W}, {S}); replace it: scripts/pick-shelters.sh <id> …", file=sys.stderr)
sh = [(f["properties"]["id"], f["properties"]["name"], f["properties"]["status"], *f["geometry"]["coordinates"]) for f in shelters]
print(f"{len(cells)} road-bearing hex cells at res {a.res}; {len(sh)} shelters ({time.time()-t0:.1f}s)", file=sys.stderr)

def osrm_get(url):
    """GET an OSRM URL; on HTTP 400 return OSRM's own JSON (code + message) instead of a bare HTTPError."""
    try:
        with urllib.request.urlopen(url, timeout=120) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        try: return json.loads(body)
        except ValueError: sys.exit(f"OSRM {e.code} at {a.osrm}: {body[:300]}")
    except urllib.error.URLError as e:
        sys.exit(f"cannot reach OSRM at {a.osrm}: {e.reason} — in the container shell $OSRM_URL is set; on a laptop use --osrm http://localhost:8080/osrm")

# Is the graph OSRM serves the one for this box? /nearest snaps to the closest road it has — even 900 km away — so look at the distance.
probe = osrm_get(f"{a.osrm}/nearest/v1/driving/{(W + E) / 2:.6f},{(S + N) / 2:.6f}")
if probe.get("code") != "Ok":
    sys.exit(f"OSRM at {a.osrm} answered {probe.get('code')}: {probe.get('message')}")
far = probe["waypoints"][0]["distance"]
if far > 2000:
    sys.exit(f"OSRM at {a.osrm} serves a graph that does not cover this box: the nearest road to the box centre is {far / 1000:.0f} km away "
             f"(the old graph is still loaded — README Phase 4 step 5: scripts/build-osrm.sh on the laptop terminal, then docker compose restart osrm)")

# 2. OSRM /table in batches: sources = hex centroids, destinations = shelters
dest = ";".join(f"{x:.6f},{y:.6f}" for *_, x, y in sh)
batch = 500 - len(sh)
rows = []
for i in range(0, len(cells), batch):
    chunk = cells[i:i + batch]
    coords = ";".join(f"{lon:.6f},{lat:.6f}" for _, lon, lat in chunk) + ";" + dest
    src = ";".join(str(k) for k in range(len(chunk)))
    dst = ";".join(str(len(chunk) + k) for k in range(len(sh)))
    rad = ";".join([str(a.radius)] * len(chunk) + ["unlimited"] * len(sh))
    url = f"{a.osrm}/table/v1/driving/{coords}?sources={src}&destinations={dst}&annotations=duration,distance&radiuses={rad}"
    d = osrm_get(url)
    while d.get("code") == "NoSegment":          # one coordinate has no road within --radius: drop that cell and ask again
        k = int((re.search(r"coordinate (\d+)", d.get("message", "")) or [0, -1])[1])
        if not 0 <= k < len(chunk):
            sys.exit(f"OSRM NoSegment on a shelter: {d.get('message')} — a shelter outside the graph? check data/shelters.geojson against the box")
        h3, lon, lat = chunk.pop(k)
        print(f"  cell {h3} ({lon:.5f}, {lat:.5f}): no road within {a.radius} m in the graph — skipped", file=sys.stderr)
        if not chunk: break
        coords = ";".join(f"{lon:.6f},{lat:.6f}" for _, lon, lat in chunk) + ";" + dest
        src = ";".join(str(k) for k in range(len(chunk))); dst = ";".join(str(len(chunk) + k) for k in range(len(sh)))
        rad = ";".join([str(a.radius)] * len(chunk) + ["unlimited"] * len(sh))
        d = osrm_get(f"{a.osrm}/table/v1/driving/{coords}?sources={src}&destinations={dst}&annotations=duration,distance&radiuses={rad}")
    if not chunk: continue
    if d.get("code") != "Ok": sys.exit(f"OSRM {d.get('code')}: {d.get('message')} ({a.osrm})")
    for (h3, lon, lat), durs, dists in zip(chunk, d["durations"], d["distances"]):
        best = min(((t, j) for j, t in enumerate(durs) if t is not None), default=None)
        if best is None: continue                      # no road within radius → no coverage
        t, j = best
        rows.append((h3, sh[j][0], sh[j][1], sh[j][2], round(t / 60, 1), round(dists[j] / 1000, 1)))
    print(f"  batch {i//batch+1}: {len(chunk)} cells", file=sys.stderr)
print(f"{len(rows)} cells reachable ({time.time()-t0:.1f}s)", file=sys.stderr)

# 3. write GeoJSON with DuckDB spatial
con.execute("CREATE TABLE reach (h3 VARCHAR, shelter_id VARCHAR, shelter_name VARCHAR, status VARCHAR, minutes DOUBLE, km DOUBLE)")
con.executemany("INSERT INTO reach VALUES (?,?,?,?,?,?)", rows)
os.makedirs(f"{ROOT}/data/coverage", exist_ok=True)
con.execute(f"""
COPY (SELECT r.h3, r.shelter_id, r.shelter_name, r.status, r.minutes, r.km, c.geom AS geometry
      FROM reach r JOIN cells c USING (h3))
TO '{ROOT}/data/coverage/coverage_hex.geojson' (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=5')
""")
con.execute(f"""
COPY (
  -- one ring per shelter and band (0–10, 10–20, 20–30 min): rings never overlap, so the map can draw them
  -- semi-transparent without two bands blending into a third colour. Cells belong to their nearest shelter.
  SELECT shelter_id, shelter_name, status, band, ST_Union_Agg(c.geom) AS geometry
  FROM (SELECT *, CASE WHEN minutes <= 10 THEN 10 WHEN minutes <= 20 THEN 20 WHEN minutes <= 30 THEN 30 END AS band FROM reach) r
  JOIN cells c USING (h3)
  WHERE band IS NOT NULL
  GROUP BY shelter_id, shelter_name, status, band
) TO '{ROOT}/data/coverage/coverage_bands.geojson' (FORMAT GDAL, DRIVER 'GeoJSON', LAYER_CREATION_OPTIONS 'COORDINATE_PRECISION=5')
""")
summary = con.execute("SELECT shelter_name, count(*) cells, round(avg(minutes),1) avg_min FROM reach GROUP BY 1 ORDER BY 2 DESC").fetchall()
for s in summary: print(f"  {s[1]:5d} cells  avg {s[2]:5.1f} min  {s[0]}", file=sys.stderr)
for f in ("coverage_hex.geojson", "coverage_bands.geojson"):
    print(f"  {f}: {os.path.getsize(f'{ROOT}/data/coverage/{f}')/1e6:.1f} MB", file=sys.stderr)
print(f"done in {time.time()-t0:.1f}s", file=sys.stderr)
