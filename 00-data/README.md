# Module 1 — Extract & query (0:30–1:10)

**Goal:** pull the community's **road network** and its **candidate shelters** (schools,
community centers, fairgrounds) from Overture Maps and OpenStreetMap-derived GeoParquet,
using DuckDB spatial SQL — with no database server.

Run [`extract.sql`](extract.sql). Output feeds Module 2 (`../01-tiles/`).

## Data sources

| Layer | Source | Theme / type | Notes |
|---|---|---|---|
| Roads | Overture Maps | `transportation` / `segment` | Public cloud release on S3 (no-sign-request) |
| Shelters | Overture Maps | `places` / `place` | Filtered to school / community_center / fairground |
| (optional) extra roads/POIs | OpenStreetMap-derived GeoParquet | — | For attributes Overture doesn't carry |

## The bounding box (pinned)

> **Placeholder — pin before the session.** A metro-area clip of Sacramento, small enough for
> a fast in-room Planetiler run (not the whole region).
>
> ```
> xmin, ymin, xmax, ymax = -121.60, 38.44, -121.35, 38.68   (placeholder)
> Overture release = <RELEASE>   (placeholder, e.g. 2026-05-21.0)
> ```

## Exercises

- **A.** Filter to a single road class (`primary`) and count features.
- **B.** Clip to a tighter bbox around one neighborhood and re-run.

## Attribution

Overture Maps © Overture Maps Foundation. OpenStreetMap © OpenStreetMap contributors (ODbL).
