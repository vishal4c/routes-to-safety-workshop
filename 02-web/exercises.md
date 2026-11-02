# Phase 3a / 3b exercises (optional)

Phase 3a and 3b happen in the browser: <http://localhost:8080/02-web/> (Codespaces: Ports → 8080 → globe → add `/02-web/`).
Do Phase 3a first (rows 0–4 added). Solutions are collapsed — try first.

What is in this folder:

| File | What it does |
|---|---|
| `index.html` | the map page: three views (Fire evac map · Base map · Shelter reach), the **Edit** panel, the routing hook for 3c |
| `steps/step1-roads.json` … `step4-final.json` | one file per **Add** row — a JSON array of MapLibre layers; each file repeats the layers of the one before and adds more |
| `solution.html` | the page with every row already added |
| `style.json` | the finished style as one standalone MapLibre style |
| `fonts/` | Noto Sans glyphs, so the labels work offline |

How a row works: its text box holds a file path (from the repo root), and **Add** / **Reload** loads that file. A layer with the
same `id` replaces the one on the map. So the exercises below edit a **copy** in `out/` (not in git), type that path in
the row 4 box, and click **Reload**. The workshop files stay untouched.

Start with the copy (container shell):
```bash
cp 02-web/steps/step4-final.json out/my-style.json
```
Open `out/my-style.json` in the editor (the repo folder is the same on the laptop).

## A — Recolour the local streets

Make the minor roads brown instead of grey.
Hint: find the layer with `"id": "roads-minor"` and its `line-color`.

<details><summary>Solution</summary>

In `out/my-style.json`, in the `roads-minor` layer, change
```text
"line-color": "#aaaaaa",
```
to
```text
"line-color": "#8d6e63",
```
Then in the **Edit** panel, type `out/my-style.json` into the row 4 box and click **Reload**.
The local streets turn brown; motorways and primary roads keep their own colours (they are `roads-major`).
A typo in the JSON shows up as a red notice with the line and column.
</details>

## B — Show only the verified shelter

Every shelter is drawn; candidates are hollow circles. Draw only the `verified` one.
Hint: a MapLibre layer can carry a `"filter"`, an expression that must be true for a feature to be drawn
(the roads layers already use one).

<details><summary>Solution</summary>

In `out/my-style.json`, add one line to the `shelters` layer, next to `"source-layer": "shelters"`:
```text
"filter": ["==", ["get", "status"], "verified"],
```
Reload row 4. One circle is left: Sierra College in Rocklin, the only shelter a county source has confirmed.
</details>

## C — Very High hazard only

Hide the Moderate and High zones so only *Very High* stays filled.

<details><summary>Solution</summary>

Add to the `hazard` layer:
```text
"filter": ["==", ["get", "FHSZ_Description"], "Very High"],
```
Reload row 4. 204 of the 355 hazard polygons stay. Colfax High School, Georgetown School
and Sierra Vista Community Center sit inside them: the three Very High shelters from Phase 1b.
</details>

## D (3b) — Why do some shelters have fewer rings?

Switch to **Shelter reach** and click Colfax High School: it has a 10-minute ring only. Count the rings per shelter in
`data/coverage/coverage_bands.geojson`, the file the **Reach rings** row loads.

<details><summary>Solution</summary>

```bash
duckdb -c "LOAD spatial; SELECT shelter_name, list(band ORDER BY band) AS bands FROM ST_Read('data/coverage/coverage_bands.geojson') GROUP BY 1 ORDER BY len(bands), 1"
```
```text
┌─────────────────────────────────────────┬──────────────┐
│              shelter_name               │    bands     │
│                 varchar                 │   int32[]    │
├─────────────────────────────────────────┼──────────────┤
│ Colfax High School                      │ [10]         │
│ Meadow Vista Community Center           │ [10, 20]     │
│ Applegate Community Center              │ [10, 20, 30] │
│ Georgetown School                       │ [10, 20, 30] │
│ Gold Country Fairgrounds & Event Center │ [10, 20, 30] │
│ Higgins Lions Community Center          │ [10, 20, 30] │
│ Lincoln Community Center                │ [10, 20, 30] │
│ Placer High School                      │ [10, 20, 30] │
│ Sierra College, Rocklin                 │ [10, 20, 30] │
│ Sierra Vista Community Center           │ [10, 20, 30] │
└─────────────────────────────────────────┴──────────────┘
```
Every map cell belongs to its **nearest shelter by road**, so the rings never overlap. Around Colfax, every cell more than
10 minutes out is closer to another shelter (Sierra Vista Community Center is 0.2 km away), so Colfax High School keeps
only its inner ring.
</details>
