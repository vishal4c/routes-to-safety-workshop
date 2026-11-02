# Phase 2 exercises (optional)

Run from the repo root, in the container shell (option C: the laptop terminal). Solutions are collapsed — try first.
Needs the Phase 2a tiles (`01-tiles/build.sh`) and the data bundle (`bash scripts/get-bundle.sh`).

Phase 2 makes the three files the app reads:

| | Artifact | Made by | From |
|---|---|---|---|
| **2a** | `out/evac.pmtiles` — one file, 8 vector layers | `01-tiles/build.sh` (Planetiler) | the GeoJSON in `data/` |
| **2b** | `data/osrm/study-area.osrm.*` — the routing graph | `scripts/build-osrm.sh` (OSRM) | an OpenStreetMap extract (`.osm.pbf`) |
| **2c** | `data/coverage/coverage_bands.geojson` — 10 / 20 / 30-minute rings per shelter | `scripts/make-coverage.py` | the routing graph + the shelters |

What is in this folder:

| File | What it does |
|---|---|
| `evac.yml` | the tile schema: which GeoJSON file becomes which layer, from which zoom, with which attributes |
| `build.sh` / `build.ps1` | runs Planetiler once with `evac.yml` and the box from `versions.env` → `out/evac.pmtiles` |
| `planetiler.jar` | Planetiler itself (from the data bundle, not in git) |

## A — Which layers are in the tiles, and from which zoom?

List every layer in `out/evac.pmtiles` with its zoom range and attributes.
Hint: `pmtiles show --metadata` prints JSON; `vector_layers` is the list.

<details><summary>Solution</summary>

```bash
pmtiles show out/evac.pmtiles --metadata | python3 -c "import json,sys; [print(l['id'], l['minzoom'], l['maxzoom'], sorted(l['fields'])) for l in json.load(sys.stdin)['vector_layers']]"
```
```text
buildings 13 14 ['height']
fire_perimeters 4 14 ['acres', 'fire_name', 'year']
hazard 4 14 ['FHSZ', 'FHSZ_Description', 'SRA']
land_cover 5 12 ['subtype']
roads 6 14 ['class', 'name', 'route_ref']
shelters 6 14 ['id', 'name', 'status', 'type']
towns 6 14 ['class', 'name', 'population']
water 7 14 ['name', 'subtype']
```
Each line matches a `- id:` block in `evac.yml`. `land_cover` and `water` start one or two zooms later than their
`min_zoom: 4`, because `min_size` drops polygons too small to see.
</details>

## B — Local streets from zoom 12 instead of 10

In `evac.yml` the `roads` layer has two rules: big roads from zoom 6, everything else from zoom 10. Change the second
rule's `min_zoom` to 12, rebuild, and compare the file size. Put the file back afterwards.

<details><summary>Solution</summary>

In `01-tiles/evac.yml`, in the second `- source: roads` rule (the one with `exclude_when`), change `min_zoom: 10` to `min_zoom: 12`. Then:

```bash
01-tiles/build.sh
ls -l out/evac.pmtiles
```
```text
6513572 bytes before → 5675871 bytes after (≈ 13 % smaller), still 1607 tiles
```
The tiles are the same, but zoom 10 and 11 no longer carry residential streets. Put it back:
```bash
git checkout 01-tiles/evac.yml
01-tiles/build.sh
```
</details>

## C — 3D buildings from zoom 12 instead of 13

Same idea for `buildings`: change its `min_zoom: 13` to `12`, rebuild, compare the size. Does the map gain much?

<details><summary>Solution</summary>

```text
6513572 bytes before → 6515309 bytes after (+1.7 KB)
```
Almost nothing changes, because the buildings rule also has `min_size: 2`. At zoom 12 nearly every footprint is under two
pixels across, so Planetiler drops it. `min_zoom` says when a layer may appear; `min_size` decides which features are big
enough to keep. Put it back with `git checkout 01-tiles/evac.yml && 01-tiles/build.sh`.
</details>

## D — What feeds the hazard layer?

The `hazard` layer is `data/hazard/fhsz.geojson`. How many polygons per hazard class?

<details><summary>Solution</summary>

```bash
duckdb -c "LOAD spatial; SELECT FHSZ_Description, count(*) AS polygons FROM ST_Read('data/hazard/fhsz.geojson') GROUP BY 1 ORDER BY 2 DESC"
```
```text
┌──────────────────┬──────────┐
│ FHSZ_Description │ polygons │
│     varchar      │  int64   │
├──────────────────┼──────────┤
│ Very High        │      204 │
│ Moderate         │       84 │
│ High             │       67 │
└──────────────────┴──────────┘
```
These three values are what the map colours in Phase 3a (`FHSZ_Description` in `02-web/steps/step2-hazard-water.json`).
</details>

## E (2b) — How big is the routing input?

OSRM builds its graph from OpenStreetMap ways. Count the ways in the study-area extract and in the small Colfax clip.

<details><summary>Solution</summary>

```bash
osmium fileinfo -e -g data.count.ways data/osm/study-area.osm.pbf
osmium fileinfo -e -g data.count.ways data/osm/colfax.osm.pbf
```
```text
256763
3340
```
The Colfax clip is about 1 % of the study area: that is why the README builds it first, in about a minute, just to watch it happen.
</details>

## F (2c) — Which shelter reaches the most ground in 10 minutes?

`data/coverage/coverage_hex.geojson` holds one H3 cell per row, with its nearest shelter by road (`shelter_name`) and the
drive time (`minutes`). Which three shelters are nearest for the most cells within 10 minutes? How many cells are more
than 30 minutes from every shelter?

<details><summary>Solution</summary>

```bash
duckdb -c "LOAD spatial; SELECT shelter_name, count(*) AS cells FROM ST_Read('data/coverage/coverage_hex.geojson') WHERE minutes <= 10 GROUP BY 1 ORDER BY 2 DESC LIMIT 3"
duckdb -c "LOAD spatial; SELECT count(*) AS over_30 FROM ST_Read('data/coverage/coverage_hex.geojson') WHERE minutes > 30"
```
```text
┌──────────────────────────┬───────┐
│       shelter_name       │ cells │
│         varchar          │ int64 │
├──────────────────────────┼───────┤
│ Lincoln Community Center │    96 │
│ Sierra College, Rocklin  │    82 │
│ Georgetown School        │    63 │
└──────────────────────────┴───────┘
┌─────────┐
│ over_30 │
│  int64  │
├─────────┤
│    1108 │
└─────────┘
```
1,108 of the 3,341 cells (a third) are more than 30 minutes from any shelter. The rings in Phase 3b stop at 30 minutes,
so those cells show no colour: that gap is the finding.
</details>
