# data-bundle — the one-week-ahead bundle

Tiny, pre-clipped inputs plus the pre-built fallback artifacts, so every participant can complete
the full pipeline regardless of laptop speed or network. **Distributed as a GitHub Release asset**
(link in the office-hours message), not committed to the repo — the large binaries are kept out to
keep `git clone` fast.

## Contents (placeholder)

| Item | Used by | Notes |
|---|---|---|
| `sacramento.osm.pbf` (metro clip) | 00-data, 01-tiles, OSRM | small bounding-box extract |
| roads / shelters GeoParquet | 00-data | pre-clipped Overture subset |
| wildfire perimeter GeoJSON | 01-tiles, 02-web | CAL FIRE / NIFC — the hazard overlay |
| flood zone GeoJSON | 01-tiles, 02-web | FEMA NFHL (Sacramento County) |
| `basemap.pmtiles` | 01-tiles / 02-web | **fallback** if the Planetiler build is slow |
| `osrm/` graph files (`.osrm*`) | 03-routing | **pre-built** routing graph for `docker-compose.yml` |

## Get it

Download the release asset into this folder before the session:

```
# (release URL added before the workshop)
```
