# 00-data — Block 2: Extract the data (0:30–1:10)

**Working dir = repo root.** Every command on this page is run from the folder you cloned
(`routes-to-safety-workshop/`), not from inside `00-data/`. `out/` already exists there.

> **DuckDB 2.0 note.** DuckDB 2.0 still reads coordinates in the order the file's CRS says. The shipped
> SQL starts with `LOAD spatial; SET geometry_always_xy = true;` — that forces lon/lat order for
> `ST_Distance_Sphere`, `ST_Read` and `COPY … (FORMAT GDAL …)`. From DuckDB 2.1 it is the default.
> If you write your own export and the points land in the ocean off Africa, this setting is what you forgot.

Time plan: 8 min talk · Lab 1a 6 min · Lab 1b 8 min · Lab 1c 6 min · each +2 min "pens down" regroup (👀) · exercises 5 min.
Legend: ⏱ bail-out time box · 👀 regroup · 🎯 checkpoint · 🧯 fallback · **[R]** everyone · **[F]** fast finishers.

---

## Lab 1a — Look around ⏱ 6 min (+2 👀)

Three queries on the Overture roads and places we already pulled into `data/overture/`.

```bash
duckdb -c ".read 00-data/01-explore.sql"
```

**Expected:** (the same three tables are pasted as comments above each query in `01-explore.sql`)

Query 1 — `DESCRIBE`: 7 columns.
```
┌─────────────────────────────────┐
│ data/overture/segments.parquet  │
│                                 │
│ id        varchar               │
│ subtype   varchar               │
│ class     varchar               │
│ subclass  varchar               │
│ name      varchar               │
│ route_ref varchar               │
│ geometry  geometry('ogc:crs84') │
└─────────────────────────────────┘
```

Query 2 — roads by `class`, drivable classes only (the `WHERE class IN (…)` is the filter Lab 1c uses). Sum = **36,294**.
```
┌──────────────┬───────┐
│    class     │   n   │
├──────────────┼───────┤
│ residential  │ 25995 │
│ tertiary     │  4333 │
│ secondary    │  2792 │
│ primary      │  1305 │
│ unclassified │  1265 │
│ motorway     │   541 │
│ trunk        │    63 │
└──────────────┴───────┘
```
(The table has 96,059 rows in total — footways, tracks and service roads are the rest. Delete the `WHERE` and watch `service` take the top spot with 43,348.)

Query 3 — places by `category`, top 15 (27,096 places in total):
```
┌─────────────────────────────┬───────┐
│          category           │   n   │
├─────────────────────────────┼───────┤
│ real_estate_agent           │  1240 │
│ NULL                        │   919 │
│ health_care                 │   559 │
│ real_estate_service         │   517 │
│ insurance_agency            │   437 │
│ financial_service           │   350 │
│ contractor                  │   349 │
│ beauty_salon                │   341 │
│ hair_salon                  │   333 │
│ mortgage_broker             │   322 │
│ christian_place_of_worship  │   289 │
│ park                        │   287 │
│ social_or_community_service │   246 │
│ automotive_repair           │   243 │
│ professional_service        │   234 │
└─────────────────────────────┴───────┘
```
👀 **Pens down:** can everyone see 36,294 when they add up the Query 2 column? Nobody sees a red `Error`?

---

## Lab 1b — Candidate shelters ⏱ 8 min (+2 👀)

```bash
duckdb -c ".read 00-data/02-shelters.sql"
```

Four queries. What to look for:

1. **`community_center` with `confidence >= 0.7`** → 19 rows. Spot the noise: **John L Sullivan Chevrolet** (0.92)
   and **Placer County Department of Child Support Services** (0.95) are "community centers".
   Category data looks authoritative and isn't.
2. **The broader shelter-ish filter** (community centers, fairgrounds, town halls, high schools, colleges, arenas):
   `high_school 39 · community_center 19 · college_university 18 · town_hall 8 · fairgrounds 7 · stadium_arena 4`.
3. **`ST_Read('data/shelters.geojson')`** → 10 rows, 1 `verified` (Sierra College, Rocklin), 9 `candidate`.
   > *This is exactly why `shelters.geojson` is hand-verified and carries a `status`; at real scale somebody still has to check.*
4. **`ST_Intersects` with the FHSZ polygons** — which shelters sit inside a **Very High** fire hazard zone?

**Expected (query 4):**
```
┌───────────────────────────────┬───────────┬──────────────────┬──────────────────┐
│             name              │  status   │       type       │ FHSZ_Description │
│            varchar            │  varchar  │     varchar      │     varchar      │
├───────────────────────────────┼───────────┼──────────────────┼──────────────────┤
│ Colfax High School            │ candidate │ school           │ Very High        │
│ Georgetown School             │ candidate │ school           │ Very High        │
│ Sierra Vista Community Center │ candidate │ community_center │ Very High        │
└───────────────────────────────┴───────────┴──────────────────┴──────────────────┘
```
The full expected output of queries 1–3 is in the comments of `02-shelters.sql`.
👀 **Pens down:** three names, all `candidate`. A shelter inside the zone it is meant to shelter people from is a finding, not a bug.

---

## Lab 1c — Export ⏱ 6 min (+2 👀)

Type **one** export by hand so you see the shape of it (explicit column list — never `SELECT *`):

```bash
duckdb -c "LOAD spatial; SET geometry_always_xy = true; COPY (SELECT id, class, subclass, name, route_ref, geometry FROM 'data/overture/segments.parquet' WHERE class IN ('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street','motorway_link','trunk_link','primary_link','secondary_link','tertiary_link')) TO 'out/roads.geojson' (FORMAT GDAL, DRIVER 'GeoJSON')"
```

Then run the rest (water polygons only, shelters, hazard, fire perimeters, buildings_auburn, land_cover):

```bash
duckdb -c ".read 00-data/03-export.sql"
```

> Why a file, not a second `-c`? `duckdb -c` with several statements works, but a dot-command (`.read`) after another
> statement on the next line does **not**. One `-c ".read file.sql"` per run.

**Expected:** 7 files in `out/` (measured: **1.3 s**, about 39 MB in total):
```
python3 -c "import os; print(sorted(os.listdir('out')))"
['buildings_auburn.geojson', 'fire_perimeters.geojson', 'hazard.geojson', 'land_cover.geojson', 'roads.geojson', 'shelters.geojson', 'water.geojson']
```

⏱ **Not done by minute 5 →** `cp data/prebuilt/out/* out/` (Git Bash / macOS / Linux; PowerShell: `Copy-Item data/prebuilt/out/* out/`).

🎯 **Checkpoint** — everyone gets the same number:
```bash
duckdb -c "LOAD spatial; SELECT count(*) FROM ST_Read('out/roads.geojson')"
```
```
┌──────────────┐
│ count_star() │
│    int64     │
├──────────────┤
│        36294 │
└──────────────┘
```
(`ST_Read` needs the `spatial` extension, hence `LOAD spatial;` in the same string. In DuckDB 2.0.0 the bare
`SELECT count(*) FROM 'out/roads.geojson'` also returns 36,294 because the extension auto-loads — but it fails offline
if `spatial` was never installed, so the card uses the explicit form.)

🧯 *Scripted line:* "Copy `data/prebuilt/out/` into `out/` and catch up at the next card."

---

## Exercises (5 min)

[`exercises.md`](exercises.md): **[R] A** primary-and-up roads · **[R] B** nearest shelter to Foresthill (*remember it for Lab 3*) · **[F] C** re-export for the Colfax box.

## Files here

| File | What |
|---|---|
| `01-explore.sql` | Lab 1a |
| `02-shelters.sql` | Lab 1b |
| `03-export.sql` | Lab 1c (also run by `scripts/make-data.sh exports`) |
| `exercises.md` | A / B / C with collapsed solutions |
| `../scripts/sql/overture.sql` | how `data/overture/` was made (DuckDB against the Overture S3 release) — read it, don't run it today; Block 5 does |
