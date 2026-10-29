---
marp: true
theme: rts
paginate: true
footer: 'Routes to Safety · FOSS4G NA 2026'
size: 16:9
---

<!-- S13 · Phase 1 starts 0:30 · 🎤 S13–S19 = 8 min total · ~1 min -->
<!-- Say: "Every road, place and building on today's map comes from one open dataset: Overture Maps. Here's what it is in one slide." -->

# Overture Maps in one slide

- Open map data, released as **GeoParquet**, in **themes**: `transportation`, `places`, `base`, `buildings`
- Today's release: **2026-09-23.1**
- Our study area, measured on that release:
  - **96,059** road segments (**36,294** drivable) · **27,096** places
  - **6,654** water rows · **12,606** buildings (Auburn only)
- Built from OpenStreetMap + other sources; licences differ by theme (ODbL / CDLA-Permissive)

<div class="credit">Attribution: © OpenStreetMap contributors · © Overture Maps Foundation — keep it on every map you publish.</div>

---

<!-- S14 · ~1 min -->
<!-- Say: "The whole planet is huge. We never download it — we ask for a rectangle, and the file format lets us read only that rectangle." -->

# bbox pushdown: read only your rectangle

Study area: **-121.40, 38.72, -120.85, 39.15** (W, S, E, N)

```sql
SELECT count(*)
FROM read_parquet('s3://overturemaps-us-west-2/release/2026-09-23.1/theme=transportation/type=segment/*')
WHERE bbox.xmin > -121.40 AND bbox.xmax < -120.85
  AND bbox.ymin >   38.72 AND bbox.ymax <   39.15;
```

- Parquet stores a `bbox` struct per row, so DuckDB can **skip** files and row groups outside it
- Planet → Placer corridor without downloading the planet

---

<!-- S15 · ~1.5 min -->
<!-- Say: "Before any maps: three SQL words. If you know a spreadsheet filter, you know SQL." -->

# SQL in 3 lines

```sql
SELECT class, count(*) AS n   -- which columns / what to compute
FROM ST_Read('data/overture/roads.geojson')
WHERE class <> 'residential'  -- which rows to keep
GROUP BY class;               -- one output row per class
```

| Word | Question it answers |
|---|---|
| `SELECT` | what do I want back? |
| `WHERE` | which rows count? |
| `GROUP BY` | count / sum **per** group |

No GIS yet — this is just a table.

---

<!-- S16 · ~1.5 min -->
<!-- Say: "Now add shapes. A predicate is a yes/no question about two shapes. Does this point sit inside that polygon?" -->

# DuckDB spatial: a predicate is a yes/no question about two shapes

```sql
INSTALL spatial; LOAD spatial;

SELECT s.name
FROM   shelters s, fhsz h
WHERE  ST_Intersects(s.geom, h.geom)
  AND  h.FHSZ_Description = 'Very High';
```

- `ST_Intersects(a, b)` → **true / false**: do the two shapes touch or overlap?
- It goes in `WHERE`, like any other condition
- Phase 1b: which shelters sit in a Very High zone?

---

<!-- S17 · ~1.5 min -->
<!-- Say: "Overture columns can hold structs. Dot into them. This is your cheat sheet — it's also on the phase card." -->

<!-- _class: small -->

# Columns cheat sheet

| You want | Raw Overture (S3) | Our `data/overture/*.geojson` |
|---|---|---|
| a place's name | `names.primary` | `name` |
| a place's category | `taxonomy.primary` | `category` |
| how sure Overture is | `confidence` (use `>= 0.7`) | same |
| road type | `class`, `subclass` | same |
| the shape | `geometry` | same |

- `scripts/fetch-overture.sh` already flattened these — today you type the right-hand column
- `categories` was removed (Sep 2026) → `taxonomy.primary` · there is **no `fairground`** category
- Never `SELECT *` on export — list columns (`road_flags[]`-style lists break the GeoJSON writer)

---

<!-- S18 · ~1 min -->
<!-- Say: "How did data/overture/ get here? We ran the extract ahead of time. You don't today — it's committed in the repo." -->

# How `data/overture/` was made

**We ran it; you don't today.**

```
duckdb → read Overture (S3) → filter to bbox
       → COPY … TO 'data/overture/<theme>.geojson'
```

- Files: `roads`, `water`, `towns`, `land_cover`, `buildings`, `places` — six themes, all GeoJSON, 24 s for the whole box
- Committed to git — no network needed in the room
- Re-run for your own town: `scripts/fetch-overture.sh` (Phase 4)

---

<!-- _class: card -->
<!-- S19 · 🧪 stays on screen for Phase 1 · working dir = repo root; out/ exists · 1a 6+2 · 1b 8+2 · 1c 6+2 · exercises 5 -->
<!-- Say: "Open a terminal at the repo root. Phase 1a — three queries, each has an expected result. Hands up when you match it." -->

# 🧪 Phase 1 — Extract the data

**1a Look around (6 min)** — `DESCRIBE` roads · roads by `class` · places by `category` → *Expected:* output on the printed card 👀
**1b Candidate shelters (8 min)** — category filter + `confidence >= 0.7` → spot the noise (a Chevrolet dealer tagged `community_center`) → open `data/shelters.geojson` → `ST_Intersects` with FHSZ 👀

**1c Export (6 min)** — write GeoJSON with SQL — the shelter-ish places from 1b, in the shape of `shelters.geojson`:
```sql
LOAD spatial; SET geometry_always_xy = true;
COPY (SELECT …, geom AS geometry FROM ST_Read('data/overture/places.geojson')
      WHERE category IN (…shelter-ish…) AND confidence >= 0.7)
TO 'out/shelter-candidates.geojson' (FORMAT GDAL, DRIVER 'GeoJSON');
```
`duckdb -c ".read 00-data/03-export.sql"` → *Expected:* 95 candidates (39 schools, 19 community centers …) 👀 — Phase 4 reuses this for your town

**Exercises:** **A** count `primary`+ roads · **B** crow-flies nearest shelter to Foresthill (remember it!) · **C (finish early)** Colfax bbox re-export
🎯 `duckdb -c "LOAD spatial; SELECT count(*) FROM ST_Read('data/overture/roads.geojson')"` → **36,294**
