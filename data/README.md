# data/ — provenance, sizes, regeneration

Everything here covers one study area: the **Placer County I-80 corridor** (Rocklin → Auburn → Colfax → Foresthill, plus the whole
Mosquito 2022 footprint). Bounding box (W,S,E,N) = **-121.40, 38.72, -120.52, 39.20** — the single source is `versions.env`
(`BBOX_*`). Sizes below were measured on 2026-10-23.

## Provenance per file

| File | Source (URL) | Release / date | Made by | Size | Rows | CRS / notes | Licence |
|---|---|---|---|---|---|---|---|
| `overture/segments.parquet` | `s3://overturemaps-us-west-2/release/2026-09-23.1/theme=transportation/type=segment` | Overture 2026-09-23.1 | `scripts/sql/overture.sql` (via `make-data.sh overture`), `subtype='road'` | 14.3 MB | 96,059 | WGS84 (`ogc:crs84`) | ODbL 1.0 |
| `overture/connectors.parquet` | `…/theme=transportation/type=connector` | 2026-09-23.1 | same | 4.7 MB | 143,316 | WGS84 | ODbL 1.0 |
| `overture/places.parquet` | `…/theme=places/type=place` | 2026-09-23.1 | same; `taxonomy.primary` aliased to `category` | 1.4 MB | 27,096 | WGS84 | CDLA-Permissive-2.0 |
| `overture/water.parquet` | `…/theme=base/type=water` | 2026-09-23.1 | same | 1.9 MB | 6,654 (1,920 polygons; rest points/lines) | WGS84, mixed geometry types | ODbL 1.0 |
| `overture/localities.parquet` | `…/theme=divisions/type=division` (`locality`, `neighborhood`) | 2026-09-23.1 | same | 7 KB | 134 | WGS84 | see `LICENSE-data.md` |
| `overture/buildings_auburn.parquet` | `…/theme=buildings/type=building`, Auburn box `AUBURN_*` | 2026-09-23.1 | same | 1.4 MB | 12,606 | WGS84 | ODbL 1.0 (+ per-source terms) |
| `overture/land_cover.parquet` | `…/theme=base/type=land_cover` | 2026-09-23.1 | same | 1.9 MB | 2,564 | WGS84 | CC-BY 4.0 (ESA WorldCover) |
| `hazard/fhsz.parquet` | CAL FIRE FRAP FHSZ ArcGIS REST (`CALFIRE_FHSZ_URL` in `versions.env`); dataset page <https://data.ca.gov/dataset/fire-hazard-severity-zone-viewer1> | SRA effective 2024-04-01; LRA recommended 2025-03-24 | `scripts/fetch_arcgis.py` + `scripts/sql/hazard.sql` (via `make-data.sh hazard`) | 5.6 MB | 355 polygons (Very High 204 · Moderate 84 · High 67) | **Stored upstream in EPSG:2226 (NAD83 / California zone 2, US feet).** We request `f=geojson` so the server reprojects to WGS84; the file here is WGS84 (lon −123.07 … −119.68, inside the −125…−114 sanity range) | CC-BY (CAL FIRE FRAP) |
| `hazard/fire_perimeters.geojson` | CAL FIRE `California_Historic_Fire_Perimeters` (`CALFIRE_PERIMETERS_URL`) | firep25_1, Apr 2026 | same; Mosquito 2022 + River 2021 only | 0.66 MB | 2 (MOSQUITO 76,771 ac · RIVER 2,619 ac) | WGS84 | CC-BY (CAL FIRE FRAP) |
| `shelters.geojson` | hand-curated; `status = verified` only for Sierra College, Rocklin (Placer County release, Mosquito 2022); `source` column per row | 2026-10 | by hand | 5 KB | 10 (1 verified, 9 candidate) | WGS84 | CC BY-SA 4.0 (materials) |
| `coverage/coverage_hex.geojson` | derived: H3 res-8 hexes × OSRM `/table` | 2026-10-23 | `scripts/make-coverage.py` | 1.4 MB | 3,341 | WGS84 | derived — ODbL (OSM roads) |
| `coverage/coverage_bands.geojson` | derived: dissolved 10/20/30-min bands | 2026-10-23 | `scripts/make-coverage.py` | 0.14 MB | 30 (10 shelters × 3 bands) | WGS84 | derived — ODbL |
| `prebuilt/out/*.geojson` | the output of Phase 1c, committed as the fallback | 2026-10-23 | `00-data/03-export.sql` (via `make-data.sh exports`) | 39 MB (7 files; cap is 40) | roads 36,294 | WGS84 | as inputs |
| `osm/study-area.osm.pbf` | Geofabrik `norcal-latest` (`OSM_EXTRACT_URL`) | latest object timestamp **2026-10-22T17:09:36Z** | `osmium extract -b BBOX -s smart` | 17.0 MB | 2,433,879 nodes · 256,763 ways · 2,142 relations | WGS84 | ODbL 1.0 |
| `osm/colfax.osm.pbf` | clip of the above to `COLFAX_*` | same | `osmium extract` | 0.39 MB | — | WGS84 | ODbL 1.0 |
| `osrm/study-area.osrm.*` | built from `study-area.osm.pbf`, car profile, MLD | 2026-10-23; image `ghcr.io/project-osrm/osrm-backend:v26.10.0-debian` | `scripts/build-osrm.sh` (15 s) | 99 MB (26 files) | — | — | ODbL 1.0 (derived from OSM) |
| `prebuilt/evac.pmtiles` | built from `prebuilt/out/*.geojson` | 2026-10-24 | `01-tiles/build.sh` (Planetiler v0.10.2, 4 s) | 6.5 MB (6,512,895 B) | 8 layers (incl. places labels), z4–14 | Web Mercator tiles | as inputs |

> Geofabrik timestamp: `osmium fileinfo -e data/osm/study-area.osm.pbf` → *Timestamps Last: 2026-10-22T17:09:36Z* (newest object in the extract; the
> header carries no replication timestamp because the file is an `osmium extract` derivative). The download time was 2026-10-23.

## What is in git vs the bundle

| In git (`git clone --depth 1`) | In `data-bundle.zip` (Release asset + USB + baked into the image) |
|---|---|
| `overture/*.parquet` (29 MB), `hazard/*` (5.9 MB), `shelters.geojson`, `coverage/*` (1.5 MB), `prebuilt/out/*.geojson` (39 MB) — about 76 MB on disk, **38 MB transferred** by `git clone --depth 1` (measured 2026-10-23), 109 MB on disk | `osm/*.osm.pbf` (17.4 MB), `osrm/*` (99 MB), `prebuilt/evac.pmtiles` (6.5 MB), `01-tiles/planetiler.jar` (93 MB) |

`scripts/get-bundle.sh` (`.ps1` on PowerShell) downloads the bundle and checks it against `CHECKSUMS.sha256`. No Git LFS.
Verify by hand from the repo root: `shasum -a 256 -c data/CHECKSUMS.sha256` (Linux: `sha256sum -c`).

## Regenerate

All commands run from the repo root; every bbox comes from `versions.env`.

```bash
scripts/make-data.sh --plan                 # print what would run, with estimated sizes — no network
scripts/make-data.sh overture               # DuckDB → data/overture/*.parquet   (reads s3://overturemaps-us-west-2 directly)
scripts/make-data.sh hazard                 # CAL FIRE REST → data/hazard/      (f=geojson → WGS84)
scripts/make-data.sh osm                    # Geofabrik norcal (~1 GB) → osmium extract → data/osm/*.osm.pbf
scripts/make-data.sh exports                # data/prebuilt/out/*.geojson       (same SQL as Phase 1c)
scripts/build-osrm.sh                       # data/osm/study-area.osm.pbf → data/osrm/study-area.osrm.*  (needs docker/finch/podman)
scripts/build-osrm.sh data/osm/colfax.osm.pbf out/osrm   # Phase 2b (optional), tiny graph — laptop terminal with Docker, or Codespaces
scripts/make-coverage.py                    # needs OSRM at http://localhost:5000 → data/coverage/*.geojson
01-tiles/build.sh                           # out/*.geojson → out/evac.pmtiles   (--prebuilt uses data/prebuilt/out)
cp out/evac.pmtiles data/prebuilt/evac.pmtiles
shasum -a 256 data/osm/* data/osrm/* data/prebuilt/evac.pmtiles 01-tiles/planetiler.jar > data/CHECKSUMS.sha256
```

## Known gaps

- `.gitignore` currently ignores `*.parquet` and `*.geojson`, `*.pmtiles`, `*.osm.pbf`. The "in git" files above need `git add -f` or a `.gitignore` update (`!data/**`) before they are committed.
