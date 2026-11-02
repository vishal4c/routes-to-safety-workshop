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

Usage:  scripts/make-coverage.py [--osrm http://localhost:5000] [--res 8]
This is Phase 2c (reach bands / isochrones) — the same /table call as 03-routing/exercises.md Stretch A, with more points, dissolved with DuckDB spatial.
"""
import argparse, json, os, re, sys, time, urllib.request
import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# KEY=value lines; an inline "# comment" and surrounding quotes are not part of the value (BBOX_W=-122.244   # west)
ENV = {k.strip(): re.sub(r"\s+#.*$", "", v).strip().strip("'\"") for k, v in
       (l.split("=", 1) for l in open(f"{ROOT}/versions.env") if "=" in l and not l.lstrip().startswith("#"))}
ap = argparse.ArgumentParser(); ap.add_argument("--osrm", default="http://localhost:5000"); ap.add_argument("--res", type=int, default=8)
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
sh = [(f["properties"]["id"], f["properties"]["name"], f["properties"]["status"], *f["geometry"]["coordinates"]) for f in shelters]
print(f"{len(cells)} road-bearing hex cells at res {a.res}; {len(sh)} shelters ({time.time()-t0:.1f}s)", file=sys.stderr)
# Phase 4 guards: each one names the step to redo instead of ending in an OSRM "HTTP Error 400".
if not sh:
    sys.exit("data/shelters.geojson has 0 shelters — Phase 4 step 4: scripts/pick-shelters.sh <ids from out/shelter-candidates.csv>")
if not cells:
    sys.exit("no road-bearing cells in the box — data/overture/roads.geojson is empty or for another box (Phase 4 step 2)")
outside = [name for _, name, _, x, y in sh if not (W <= x <= E and S <= y <= N)]
if outside:
    sys.exit(f"{len(outside)} of {len(sh)} shelters are outside the box in versions.env ({', '.join(outside[:3])}…) — Phase 4 step 4")
# The graph OSRM serves must cover this box: "code":"Ok" alone proves nothing, the snapping distance does.
def snap_m(x, y):
    with urllib.request.urlopen(f"{a.osrm}/nearest/v1/driving/{x:.6f},{y:.6f}", timeout=30) as r:
        return json.load(r)["waypoints"][0]["distance"]
for name, x, y in [("the box centre", (W + E) / 2, (S + N) / 2)] + [(n, x, y) for _, n, _, x, y in sh]:
    d = snap_m(x, y)
    if d > 5000:
        sys.exit(f"OSRM snaps {name} to a road {d/1000:.0f} km away: it still serves a graph for another area — "
                 "Phase 4 step 5 (scripts/build-osrm.sh, then restart osrm)")

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
    try:
        with urllib.request.urlopen(url, timeout=120) as r:
            d = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"OSRM /table answered {e.code}: {e.read().decode(errors='replace')[:200]} — scripts/check-phase4.sh names the step to redo")
    if d.get("code") != "Ok": sys.exit(f"OSRM error: {d}")
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
