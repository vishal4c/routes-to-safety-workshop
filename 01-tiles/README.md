# Block 3 · Lab 2a — Build the basemap (1:20 → 1:30)

**Goal:** turn the GeoJSON you exported in Lab 1c (`out/*.geojson`) into **one PMTiles file** with
Planetiler, then check it. Labs 2b/2c (render + restyle) continue in [`../02-web/`](../02-web/).

Working directory for every command: **the repo root**.

## Lab 2a · Build (7 min + 2)

```bash
java -Xmx2g -jar 01-tiles/planetiler.jar generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force
pmtiles show out/evac.pmtiles
```

Or the same thing with a timer and a fallback: `01-tiles/build.sh` (PowerShell: `01-tiles/build.ps1`).

**Expected** (`pmtiles show`): `tile type: mvt`, `min zoom: 4`, `max zoom: 14`, bounds `-121.40 38.72 … -120.52 39.20`,
8 vector layers, ≈ 7.1 MB, build time ≈ 4 s on a 2023 laptop (the first run also spends a few seconds starting the JVM).

```
pmtiles show out/evac.pmtiles --metadata | grep -o '"id":"[a-z_]*"'
"id":"buildings_auburn" "id":"fire_perimeters" "id":"hazard" "id":"land_cover" "id":"places" "id":"roads" "id":"shelters" "id":"water"
```

⏱ **No PMTiles by minute 5?** `cp data/prebuilt/evac.pmtiles out/` and move on — same file, built with the same command.

🧯 `out/roads.geojson missing` → you skipped Lab 1c: `cp data/prebuilt/out/*.geojson out/` or run `01-tiles/build.sh --prebuilt`.
🧯 `java: command not found` → see [`../setup/README.md`](../setup/README.md) (Temurin 21). `Unsupported class file major version` → your Java is older than 21.
🧯 `planetiler.jar` missing → `scripts/get-bundle.sh` downloads it (it is not in git), or `curl -L -o 01-tiles/planetiler.jar https://github.com/onthegomap/planetiler/releases/download/v0.10.2/planetiler.jar`.

## What's here

| File | What |
|---|---|
| [`evac.yml`](evac.yml) | Planetiler **custommap schema**: 8 local GeoJSON sources → 8 layers (incl. `places`: city/town labels from z6, villages z9, hamlets z11), with `min_zoom`, `min_size` and the attributes each layer keeps. Read it: this is the whole "tile schema" lesson. |
| [`build.sh`](build.sh) / [`build.ps1`](build.ps1) | The one-line build above plus `--bounds` from `versions.env`, a timer and the `--prebuilt` fallback. |
| `planetiler.jar` | Planetiler v0.10.2 (89 MB, **not in git** — comes from `scripts/get-bundle.sh` or the curl above). |

## The schema in one paragraph

Every `source` is a local file, so the build makes zero network calls. Each `layer` lists `features` rules:
`include_when` / `exclude_when` filter on a property (big roads from zoom 6, local streets from zoom 10),
`min_zoom` / `max_zoom` bound where a layer exists (land cover stops at 12, Auburn buildings start at 13),
`min_size` drops features smaller than N pixels at a zoom, and `attributes` whitelist the properties that survive
into the tile (anything not listed is gone — that is how tiles stay small). Change one number, rebuild in 4 s, reload the map.

## Exercises (if you finish early)

- **[R]** Raise `roads` local-street `min_zoom` from 10 to 12 and rebuild: how much smaller is the file? (`ls -la out/evac.pmtiles`)
- **[M]** Add `subclass` to the roads attributes and use it in 02-web to dash `motorway_link` ramps.
- **[F]** Add an 8th layer from `out/water.geojson` filtered to `subtype = 'river'` only (`include_when: { subtype: river }`).

## Instructor demo after the lab (~1 min)

`pmtiles serve out --port 8077` then open Maputnik with `02-web/style.json` — the same tiles in a visual style editor.
