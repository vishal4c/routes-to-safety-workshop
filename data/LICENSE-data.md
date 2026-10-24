# Data licences and attribution

The code in this repository is MIT and the teaching materials are CC BY-SA 4.0 (see `LICENSE`, `LICENSE-materials`).
**The data keeps the licences of its sources.** Anything derived from OpenStreetMap-based data (roads, water, buildings, the
OSRM graph, coverage polygons) must be shared under ODbL 1.0 if you publish a derivative database.

## Required attribution string (use verbatim on maps, in `evac.yml`, in the demo)

> © OpenStreetMap contributors · © Overture Maps Foundation · Fire Hazard Severity Zones: CAL FIRE FRAP (CC-BY) · Land cover: ESA WorldCover (CC-BY)

## Per source

| Data | Licence | Where it appears | Obligation |
|---|---|---|---|
| Overture **transportation** (segments, connectors) | ODbL 1.0 (OpenStreetMap-derived) | `overture/segments.parquet`, `connectors.parquet`, roads layer | attribute OSM + Overture; share-alike for derived databases |
| Overture **places** | CDLA-Permissive-2.0 | `overture/places.parquet` (Phase 1) | attribute Overture; no share-alike |
| Overture **buildings** | ODbL 1.0 (OpenStreetMap and other contributors; per-source terms in the data's `sources`) | `overture/buildings_auburn.parquet` | attribute; share-alike for derived databases |
| Overture **base** — water | ODbL 1.0 (OpenStreetMap-derived) | `overture/water.parquet` | attribute OSM + Overture; share-alike |
| Overture **base** — land cover | CC-BY 4.0 (ESA WorldCover) | `overture/land_cover.parquet` | attribute ESA WorldCover |
| Overture **divisions** (localities) | see Overture attribution page; mostly ODbL (OSM) | `overture/localities.parquet` | attribute Overture |
| OpenStreetMap extract | ODbL 1.0 — <https://www.openstreetmap.org/copyright> | `osm/*.osm.pbf`, `osrm/*` | "© OpenStreetMap contributors"; share-alike |
| CAL FIRE FRAP — Fire Hazard Severity Zones; Historic Fire Perimeters | CC-BY (data.ca.gov `license_id: cc-by`; "No restrictions on public use") | `hazard/*` | credit CAL FIRE FRAP |
| ESA WorldCover (via Overture land cover) | CC-BY 4.0 | `land_cover` | "ESA WorldCover" credit |
| `shelters.geojson` | CC BY-SA 4.0 (original compilation; each row cites its `source`) | `shelters.geojson` | credit the workshop repo |

> **Verification status.** The per-theme assignments for transportation, places, buildings and base follow Overture's published
> scheme and `planning/research/B-overture.md` (§ OSM-derived themes are ODbL). On 2026-10-23 the page
> <https://docs.overturemaps.org/attribution/> only listed the **addresses** theme (we do not use it); the per-theme sub-pages
> returned 404. **Re-check each theme's licence against the `sources`/licence metadata of release 2026-09-23.1 before
> redistributing the data outside the workshop.**

## Disclaimer

Teaching example, not an official evacuation resource. Drive-time estimates assume no traffic and no closures. In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.
CAL FIRE hazard zones are statutory planning data, not a prediction of where a specific fire will burn.
