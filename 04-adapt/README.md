# 04-adapt — Block 5: Reproduce, adapt, scale (2:37–3:00)

Everything in this workshop is a pipeline of scripts reading one file, `versions.env`. Change the bounding box and the same
pipeline builds your town. This lab shows you what it *would* do — offline, in seconds.

## Lab 4 — Point it at your town ⏱ 6 min (+2 👀)  · working dir = repo root

1. Open `versions.env` and change the four `BBOX_*` values to a box around your own community (W, S, E, N in lon/lat;
   [bboxfinder.com](http://bboxfinder.com) draws one). Keep it under about 0.5 sq. degrees for a laptop.
2. Print the plan — **no network, nothing is written**:

```bash
scripts/make-data.sh --plan
```

3. Read it: which Overture queries run, which files appear, how big they will be. The size estimates scale with the box area.

**Expected** with the default Placer I-80 box (`-121.40,38.72,-120.52,39.20`):
```
Study area bbox: -121.40,38.72,-120.52,39.20  (0.422 sq. degrees)   Overture release: 2026-09-23.1

== overture → data/overture/*.parquet  (DuckDB reads s3://overturemaps-us-west-2/release/2026-09-23.1 directly, bbox pushdown)
   segments.parquet  (roads: id, subtype, class, subclass, name, route_ref)   ~17.7 MB
   connectors.parquet                                                       ~6.3 MB
   places.parquet    (id, name, category, basic_category, confidence, address) ~2.1 MB
   water.parquet · localities.parquet · land_cover.parquet · buildings_auburn.parquet (Auburn bbox only)

== hazard → data/hazard/   (CAL FIRE ArcGIS REST, f=geojson so the server reprojects EPSG:2226 ft → WGS84)
   fhsz.parquet            FHSZ 2024/25 SRA+LRA polygons intersecting the bbox   ~1–5 MB
   fire_perimeters.geojson Mosquito 2022 + River 2021 (clipped to bbox)           <1 MB

== osm → data/osm/study-area.osm.pbf + colfax.osm.pbf  (osmium extract from https://download.geofabrik.de/north-america/us/california/norcal-latest.osm.pbf, ~1 GB download)

== exports → data/prebuilt/out/*.geojson  (the fallback copy of what attendees produce in Lab 1c; same SQL as 00-data/03-export.sql)

(plan only — nothing was downloaded or written)
```
Edit the box and the first line and the three `~… MB` estimates change.

👀 **Pens down:** what is the new area in sq. degrees, and which estimate grew the most?

⏱ If it misbehaves after your edit: no spaces around `=` in `versions.env`; `git checkout versions.env` restores the default box.

**Homework — the real run** (needs network; ~1 GB OSM download for the Geofabrik step):
```bash
scripts/make-data.sh                  # overture + hazard + osm + exports
scripts/build-osrm.sh                 # routing graph (needs docker / finch / podman)
01-tiles/build.sh                     # out/evac.pmtiles
```
You will also need to replace `data/shelters.geojson` with shelters for your town (id, name, status, type, town, source —
mark everything `candidate` until a primary source says otherwise) and the Auburn box (`AUBURN_*`) for the buildings layer.
The FHSZ layer only exists for California; for elsewhere, see below.

## Swap the hazard

The hazard layer is one polygon file with a class column. Replace it, keep the style.

| Hazard | Source | Query |
|---|---|---|
| **Flood** — FEMA National Flood Hazard Layer (US Government work, public domain) | `https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer` (flood-hazard-zones sub-layer; layer 28 in `NFHL_Print/NFHLQuery/MapServer`) | same pattern as `scripts/fetch_arcgis.py`: `…/query?where=1=1&geometry=W,S,E,N&geometryType=esriGeometryEnvelope&inSR=4326&outFields=*&f=geojson` — then style by the flood-zone field (check the layer's field list; `A`/`AE` are the mapped high-risk zones). Untested in the workshop build |
| **Wildfire, live** — CAL FIRE active incidents | `https://incidents.fire.ca.gov/umbraco/Api/IncidentApi/GeoJsonList` (undocumented, no SLA; page it backs: <https://www.fire.ca.gov/incidents>) | points with `Name`, `AcresBurned`, `PercentContained`, `IsActive` |
| **Evacuation zones, live** — Cal OES aggregation | `https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services/CA_EVACUATIONS_CalOESHosted_view/FeatureServer/0` | only publishes zones with an active order/warning; empty most days |
| **Wildfire, static** — CAL FIRE FHSZ (what we use) | `CALFIRE_FHSZ_URL` in `versions.env` | `scripts/make-data.sh hazard` |

> ⚠️ **Going live raises the stakes on every S10 caveat.** A static hazard layer that is out of date is embarrassing; a live
> perimeter that is out of date, or a "safe" route through a road nobody has mapped as closed, can hurt someone. Before you
> wire a live feed into anything people will use: show the feed's own timestamp on the map, say what the data does *not*
> contain (shelter status, closures, capacity, drive time ≠ evacuation time), and send people to the official sources.

> Teaching example, not an official evacuation resource. Drive-time estimates assume no traffic and no closures. In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.

## Laptop → planet

| What we did on a laptop | What changes at scale |
|---|---|
| DuckDB reads Overture over S3 with bbox pushdown | Same query, bigger box. For a state/country, filter by `theme`/`type` and write one parquet per region; use `bbox` columns, not `ST_Intersects`, to prune. Overture also ships a CLI (`overturemaps download`). |
| Planetiler `generate-custom` from GeoJSON, 4 s | Planetiler's built-in profiles read OSM PBF directly and can build a planet on one large machine (see the Planetiler docs for current times and RAM); `--bounds` limits it to a region. Output is the same PMTiles. |
| PMTiles on any static host (Range requests) | S3 + CloudFront / Cloudflare R2. No tile server. |
| OSRM MLD graph for 0.4 sq. degrees, 99 MB, 15 s | Large graphs need far more RAM and disk to build (see the OSRM wiki); use regional Geofabrik extracts, or Valhalla / GraphHopper / OpenRouteService if you need isochrones, traffic profiles or alternatives. |
| `/table` 10 shelters × ~3,300 hexes | `--max-table-size` grows memory quadratically; batch the requests (as `scripts/make-coverage.py` does). |

More: slides S35–S37 (laptop → planet, in the wild, learn more).
