# Block 2 exercises (5 min)

Run from the repo root. Solutions are collapsed — try first.

## [R] A — How many `primary`-or-bigger roads?

Count the road segments in `data/overture/segments.parquet` whose `class` is `motorway`, `trunk` or `primary`.

<details><summary>Solution</summary>

```bash
duckdb -c "SELECT count(*) AS primary_plus FROM 'data/overture/segments.parquet' WHERE class IN ('motorway','trunk','primary')"
```
```
┌──────────────┐
│ primary_plus │
│    int64     │
├──────────────┤
│         1909 │
└──────────────┘
```
= 541 motorway + 63 trunk + 1,305 primary (the numbers from Lab 1a).
</details>

## [R] B — Nearest shelter to Foresthill, as the crow flies

Foresthill is at lon/lat **(-120.8182, 39.0199)**. Which of the 10 shelters in `data/shelters.geojson` is closest in a straight line, and how far?
Hint: `ST_Distance_Sphere(a, b)` returns metres, and needs `SET geometry_always_xy = true;` in DuckDB 2.0.

<details><summary>Solution</summary>

```bash
duckdb -c "LOAD spatial; SET geometry_always_xy = true; SELECT name, round(ST_Distance_Sphere(geom, ST_Point(-120.8182, 39.0199)) / 1000, 1) AS km FROM ST_Read('data/shelters.geojson') ORDER BY km LIMIT 3"
```
```
┌───────────────────────────────┬────────┐
│             name              │   km   │
│            varchar            │ double │
├───────────────────────────────┼────────┤
│ Georgetown School             │   12.4 │
│ Sierra Vista Community Center │   14.9 │
│ Applegate Community Center    │   15.1 │
└───────────────────────────────┴────────┘
```
**Georgetown School, 12.4 km.**

> **Remember this for Lab 3.** The road network will disagree: the American River canyon sits between Foresthill and
> Georgetown, so by road Georgetown is about an hour away, not minutes. Nearest on the map ≠ nearest by road.
</details>

## [F] C — Re-export the roads for the Colfax box

Re-export `roads.geojson`, but only the drivable roads that touch the Colfax clip in `versions.env`
(`COLFAX_W/S/E/N` = -121.02, 39.05, -120.90, 39.13) to `out/roads_colfax.geojson`. How many features?
Hint: `ST_MakeEnvelope(xmin, ymin, xmax, ymax)` + `ST_Intersects`.

<details><summary>Solution</summary>

```bash
duckdb -c "LOAD spatial; SET geometry_always_xy = true; COPY (SELECT id, class, subclass, name, route_ref, geometry FROM 'data/overture/segments.parquet' WHERE class IN ('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street','motorway_link','trunk_link','primary_link','secondary_link','tertiary_link') AND ST_Intersects(geometry, ST_MakeEnvelope(-121.02, 39.05, -120.90, 39.13))) TO 'out/roads_colfax.geojson' (FORMAT GDAL, DRIVER 'GeoJSON'); SELECT count(*) AS colfax_roads FROM ST_Read('out/roads_colfax.geojson')"
```
```
┌──────────────┐
│ colfax_roads │
│    int64     │
├──────────────┤
│          736 │
└──────────────┘
```
**736** features (roads that merely cross the box edge are included; requiring them to lie fully inside gives 694).
</details>
