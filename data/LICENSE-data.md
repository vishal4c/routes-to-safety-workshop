# Data licences and attribution

The code in this repository is MIT and the teaching materials are CC BY-SA 4.0 (see `LICENSE`, `LICENSE-materials`).
**The data keeps the licences of its sources.** Anything derived from OpenStreetMap-based data (roads, water, buildings, the
OSRM graph, coverage polygons) must be shared under ODbL 1.0 if you publish a derivative database.

## Required attribution string (use verbatim on maps, in `evac.yml`, in the demo)

> © OpenStreetMap contributors · © Overture Maps Foundation · Fire Hazard Severity Zones: CAL FIRE FRAP (CC-BY) · Land cover: ESA WorldCover (CC-BY)

## Per source

| Data | Licence | Where it appears | Obligation |
|---|---|---|---|
| Overture **transportation** (segments, connectors) | ODbL 1.0 (OpenStreetMap-derived) | `overture/roads.geojson` → roads layer | attribute OSM + Overture; share-alike for derived databases |
| Overture **places** | CDLA-Permissive-2.0 | `overture/places.geojson` (Phase 1 only — not in the tiles) | attribute Overture; no share-alike |
| Overture **buildings** | ODbL 1.0 (OpenStreetMap and other contributors; per-source terms in the data's `sources`) | `overture/buildings.geojson` | attribute; share-alike for derived databases |
| Overture **base** — water | ODbL 1.0 (OpenStreetMap-derived) | `overture/water.geojson` | attribute OSM + Overture; share-alike |
| Overture **base** — land cover | CC-BY 4.0 (ESA WorldCover) | `overture/land_cover.geojson` | attribute ESA WorldCover |
| Overture **divisions** (localities) | see Overture attribution page; mostly ODbL (OSM) | `overture/towns.geojson` | attribute Overture |
| OpenStreetMap extract | ODbL 1.0 — <https://www.openstreetmap.org/copyright> | `osm/*.osm.pbf`, `osrm/*` | "© OpenStreetMap contributors"; share-alike |
| CAL FIRE FRAP — Fire Hazard Severity Zones; Historic Fire Perimeters | CC-BY (data.ca.gov `license_id: cc-by`; "No restrictions on public use") | `hazard/*` | credit CAL FIRE FRAP |
| ESA WorldCover (via Overture land cover) | CC-BY 4.0 | `land_cover` | "ESA WorldCover" credit |
| `shelters.geojson` | CC BY-SA 4.0 (original compilation; each row cites its `source`) | `shelters.geojson` | credit the workshop repo |

> **Verification status.** The per-theme assignments for transportation, places, buildings and base follow Overture's published
> scheme and `planning/research/B-overture.md` (§ OSM-derived themes are ODbL). On 2026-10-23 the page
> <https://docs.overturemaps.org/attribution/> only listed the **addresses** theme (we do not use it); the per-theme sub-pages
> returned 404. **Re-check each theme's licence against the `sources`/licence metadata of release 2026-09-23.1 before
> redistributing the data outside the workshop.**

## Provenance — how every file in `data/` was made

All boxes come from `versions.env`; every file is GeoJSON (WGS84 lon/lat). Study area: Placer County I-80 corridor, W,S,E,N = -121.40, 38.72, -120.52, 39.20.

| File | Source | Made by | Features |
|---|---|---|---|
| `overture/roads.geojson` | Overture 2026-09-23.1 `theme=transportation/type=segment`, `subtype='road'`, drivable classes | `scripts/fetch-overture.sh` | 36,294 |
| `overture/water.geojson` | `theme=base/type=water`, polygons only | same | 1,920 |
| `overture/towns.geojson` | `theme=divisions/type=division`, `subtype='locality'` | same | 121 |
| `overture/land_cover.geojson` | `theme=base/type=land_cover` (ESA WorldCover) | same | 2,564 |
| `overture/buildings.geojson` | `theme=buildings/type=building`, Auburn box (`BUILDINGS_*`) | same | 12,606 |
| `overture/places.geojson` | `theme=places/type=place` (points of interest) | same | 27,096 |
| `hazard/fhsz.geojson` | CAL FIRE FRAP Fire Hazard Severity Zones (ArcGIS REST, `f=geojson` → server reprojects EPSG:2226 ft → WGS84) | `scripts/fetch-hazard.sh` | 355 polygons (Very High 204 · Moderate 84 · High 67) |
| `hazard/fire_perimeters.geojson` | CAL FIRE Historic Fire Perimeters — Mosquito 2022 (76,771 ac), River 2021 (2,619 ac) | same | 2 |
| `shelters.geojson` | hand-curated; `status=verified` only for Sierra College (Placer County release, Mosquito 2022); `source` per row | by hand | 10 |
| `coverage/coverage_hex.geojson` · `coverage_bands.geojson` | derived: H3 res-8 cells × OSRM `/table`, dissolved into 10/20/30-min bands | `scripts/make-coverage.py` | 3,341 · 30 |
| `osm/study-area.osm.pbf` (bundle) | Geofabrik `norcal-latest` (OSM, 2026-10-22), `osmium extract -s smart` | `scripts/fetch-osm.sh` | 17 MB |
| `osm/colfax.osm.pbf` (bundle) | clip of the above to -121.02, 39.05, -120.90, 39.13 (Phase 2b demo) | `osmium extract` | 0.4 MB |
| `osrm/study-area.osrm.*` (bundle) | OSRM MLD graph, car profile, from `study-area.osm.pbf` | `scripts/build-osrm.sh` | 99 MB |
| `prebuilt/evac.pmtiles` (bundle) | Planetiler v0.10.2 over the files above (`01-tiles/evac.yml`) | `01-tiles/build.sh` | 8 layers, z4–14 |

"(bundle)" = not in git; `scripts/get-bundle.sh` downloads `data-bundle.zip` from the GitHub Release and checks it against `CHECKSUMS.sha256`.

## Disclaimer

Teaching example, not an official evacuation resource. Drive-time estimates assume no traffic and no closures. In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.
CAL FIRE hazard zones are statutory planning data, not a prediction of where a specific fire will burn.
