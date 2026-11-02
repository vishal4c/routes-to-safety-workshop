# Phase 0 exercises (optional)

Run from the repo root, in the container shell (option C: the laptop terminal). Solutions are collapsed — try first.

What is in this folder:

| File | What it does |
|---|---|
| `check_setup.py` | checks every tool (DuckDB, Java, pmtiles, Node), OSRM and the web server; prints the tier and the next command |
| `hello-geo.sql` | the Phase 0 checkpoint: reads `data/shelters.geojson` and finds the shelter nearest to Colfax as the crow flies |

The checkpoint line every machine must print:
```text
OK — DuckDB 2.0.0 · 10 shelters (1 verified, 9 candidate) · nearest to Colfax (crow-flies): Sierra Vista Community Center, 0.2 km
```

## A — How many shelters per status?

`hello-geo.sql` counts verified and candidate shelters with `FILTER`. Write the same count with `GROUP BY`.

<details><summary>Solution</summary>

```bash
duckdb -c "LOAD spatial; SELECT status, count(*) AS n FROM ST_Read('data/shelters.geojson') GROUP BY status ORDER BY n DESC"
```
```text
┌───────────┬───────┐
│  status   │   n   │
│  varchar  │ int64 │
├───────────┼───────┤
│ candidate │     9 │
│ verified  │     1 │
└───────────┴───────┘
```
Only Sierra College is `verified` (the Mosquito Fire shelter in 2022); everything else waits for a county source.
</details>

## B — Nearest shelter to Auburn, as the crow flies

`hello-geo.sql` measures from Colfax `(-120.9533, 39.1007)`. Measure from downtown Auburn `(-121.0769, 38.8966)` instead
and list the three closest shelters.
Hint: `ST_Distance_Sphere(a, b)` returns metres and needs `SET geometry_always_xy = true;`.

<details><summary>Solution</summary>

```bash
duckdb -c "LOAD spatial; SET geometry_always_xy = true; SELECT name, round(ST_Distance_Sphere(geom, ST_Point(-121.0769, 38.8966)) / 1000, 1) AS km FROM ST_Read('data/shelters.geojson') ORDER BY km LIMIT 3"
```
```text
┌─────────────────────────────────────────┬────────┐
│                  name                   │   km   │
│                 varchar                 │ double │
├─────────────────────────────────────────┼────────┤
│ Gold Country Fairgrounds & Event Center │    0.4 │
│ Placer High School                      │    0.5 │
│ Meadow Vista Community Center           │   11.7 │
└─────────────────────────────────────────┴────────┘
```
Two shelters within half a kilometre — Auburn is well covered. Phase 3c asks the same question by road.
</details>

## C — Do the tools match the pins?

Every version the workshop needs is pinned in `versions.env`. Compare the DuckDB, Java and pmtiles pins with what is installed.

<details><summary>Solution</summary>

```bash
grep -E '^(DUCKDB|JAVA|PMTILES)_VERSION' versions.env
duckdb --version
java -version
pmtiles version
```
```text
DUCKDB_VERSION=2.0.0
JAVA_VERSION=21
PMTILES_VERSION=1.31.2
v2.0.0 (Cyanoptera) d54cbbe3df
openjdk version "21.0.13" 2026-10-20 LTS
pmtiles 1.31.2, commit a3e4951ea6a0477b784c27c1dcbfd9c130878c5a, built at 2026-07-22T18:59:03Z
```
All three match. `check_setup.py` runs the same comparison; `scripts/check-versions.sh` makes CI fail when a file repeats a stale pin.
</details>

## D (finish early, needs routing) — Ask OSRM for the nearest road

Options A and B only (option C has no OSRM). Ask OSRM which road point is closest to Colfax `(-120.9533, 39.1007)`.
`$OSRM_URL` is preset in the container shell.

<details><summary>Solution</summary>

```bash
curl -s "$OSRM_URL/nearest/v1/driving/-120.9533,39.1007"
```
```text
{"code":"Ok","waypoints":[{"nodes":[…],"hint":"…","location":[-120.953279,39.100779],"name":"","distance":8.956438483}]}
```
`"code":"Ok"` and a `distance` of about 9 m: the routing graph is loaded and the point snaps to a road next to it.
A distance of thousands of metres would mean the graph covers another area (Phase 4 explains why).
</details>
