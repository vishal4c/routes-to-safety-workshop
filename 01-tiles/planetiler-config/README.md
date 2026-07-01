# Planetiler config — basemap + hazard/water layers

**Placeholder.** The Planetiler profile/schema that defines the workshop basemap lives here.

Planned layers (pin exact filters + zoom ranges before the session):

| Layer | Source | Notes |
|---|---|---|
| `roads` | Overture transportation | class-filtered; drives the visible street network |
| `water` | Overture / Natural Earth | restyled live in Module 2 (web) |
| `shelters` | Overture places (school/community_center/fairground) | route destinations |
| `hazard` | CAL FIRE / NIFC wildfire perimeter | rendered as the hazard overlay |

A ready-to-use profile (`evac-profile.yml` or a small Java profile) will be committed here.
Until then, `../build.sh` references it as a placeholder path.
