# Module 2 — Build the basemap (1:20–2:05)

**Goal:** turn the extracted region into your **own vector tiles** with Planetiler, package
them as a single **PMTiles** file, and hand them to Module `../02-web/` for rendering.

This is the one stage you build in full. Run [`build.sh`](build.sh) → `basemap.pmtiles`.

> **Fallback:** a pre-built `basemap.pmtiles` ships in [`../data-bundle/`](../data-bundle/), so a
> slow or failed Java build never blocks you.

## What's here

- [`build.sh`](build.sh) — Planetiler → `basemap.pmtiles`.
- [`planetiler-config/`](planetiler-config/) — profile/schema for the basemap layers, including
  the hazard and water layers you'll restyle in Module 2 (web).

## Layers (placeholder)

streets · water · designated shelters · hazard (wildfire perimeter) — final layer list and
zoom ranges pinned in `planetiler-config/` before the session.
