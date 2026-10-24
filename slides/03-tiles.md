---
marp: true
theme: rts
paginate: true
footer: 'Routes to Safety · FOSS4G NA 2026'
size: 16:9
---

<!-- S20 · Phase 2 → 3 starts 1:20 · 🎤 S20–S26 = 9 min total · ~1 min -->
<!-- Say: "Welcome back. We have GeoJSON. A browser can't draw 36,294 roads fast from that — so we cut the map into tiles." -->

# What is a vector tile?

- The map is cut into a grid of squares: **z / x / y**
- Each tile holds **geometry + attributes**, not pixels
- The browser draws them — so we can **restyle without re-building**
- Zoom 4–14 for our corridor, named layers: `roads` · `water` · `hazard` · `fire_perimeters` · `shelters` · `buildings_auburn`

```
/{z}/{x}/{y}  →  one tile, all layers inside
```

---

<!-- S21 · ~2 min -->
<!-- Say: "Planetiler turns our GeoJSON into tiles. We describe the layers in a YAML file — no code. Note: local_path only, so it makes zero network calls." -->

# Planetiler + `evac.yml`, annotated

```yaml
schema_name: Routes to Safety
attribution: © OpenStreetMap contributors · © Overture Maps Foundation  # shown in the map
sources:
  roads: { type: geojson, local_path: out/roads.geojson }    # local_path only → offline
  hazard: { type: geojson, local_path: out/hazard.geojson }  # missing file = fails fast
layers:
  - id: roads
    features: [{ source: roads, geometry: line, min_zoom: 6,
      attributes: [{ key: class, tag_value: class }] }]
  - id: hazard
    features: [{ source: hazard, geometry: polygon, min_zoom: 4 }]
```

- Planetiler's YAML has **no GeoParquet source** → that's why Phase 1 exports GeoJSON
- Illustrative excerpt; the full file is `01-tiles/evac.yml`

---

<!-- S22 · ~1.5 min -->
<!-- Say: "One file, many tiles. PMTiles lets the browser ask for just the bytes it needs — but only if your server supports Range requests." -->

# PMTiles + Range requests

- **PMTiles** = all tiles in **one file** with an index — no tile server
- The browser sends `Range: bytes=…` and gets only the tiles it needs
- The server must answer **206 Partial Content**

<div class="warn">

**Trap:** `python -m http.server` ignores Range → PMTiles fails.
Use Caddy (:8080) or `npx serve -l 8080 .`

</div>

```
curl -sI -H "Range: bytes=0-15" URL | head -1   # want: 206
```

---

<!-- S23 · ~1.5 min -->
<!-- Say: "The style is JSON that says which layer, which colour. Two expressions do most of the work: match for categories, step for numbers." -->

# MapLibre style: `match` and `step`

```json
"fill-color": ["match", ["get", "FHSZ_Description"],
  "Moderate",  "#fdbb84",
  "High",      "#e34a33",
  "Very High", "#b30000",
  "#cccccc"]
```
```json
"line-width": ["step", ["zoom"], 0.6, 10, 1.2, 13, 1.6]
```

- `match` — one output per **category** (hazard class → OrRd)
- `step` — one output per **range** (zoom → width)
- Last `match` item = fallback value

---

<!-- S24 · ~1 min demo -->
<!-- Say: "Before you restyle, look inside your own tiles. 60 seconds: open the PMTiles viewer, click a hazard polygon, read its properties." -->

# Inspect your tiles

`pmtiles show out/evac.pmtiles` → layers, zoom range · click a feature to see its properties

| `FHSZ_Description` | Colour |
|---|---|
| Moderate | `#fdbb84` |
| High | `#e34a33` |
| Very High | `#b30000` |

- Case and spelling must match **exactly** — `"Very High"`, not `"very_high"`
- `FHSZ` is also there as 1 | 2 | 3
- Source: CAL FIRE FRAP (CC-BY)

---

<!-- _class: card -->
<!-- S25 · 🧪 stays on screen for Phase 2a → 3b · 2a 7+2 · 3a 20+2 -->
<!-- Say: "Phase 2a: build your tiles. Command is on the card. By minute 5 if there's no PMTiles file, copy the prebuilt one." -->

# 🧪 Phase 2a → 3b — Build and style the map

**Open the page:** Codespaces → Ports tab → 8080 → globe · Docker → `http://localhost:8080/02-web/` · Native → `npx serve -l 8080 .` then the same URL

**2a Build the tiles (7 min)**
```
java -Xmx2g -jar 01-tiles/planetiler.jar generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force
pmtiles show out/evac.pmtiles
```
*Expected:* 8 layers, zoom 4–14, ≈ 6.5 MB 👀 ⏱ no PMTiles by minute 5 → `cp data/prebuilt/evac.pmtiles out/`

**3a Serve & render (8 min)** — in `02-web/index.html` find `// STEP 1: paste here` → paste `steps/step1-roads.json` → reload; add `AttributionControl` → *Expected:* grey roads + attribution bottom-right 👀

**3a Restyle (12 min)** — hazard `match` (OrRd) · water fill · shelters: filled = verified, hollow = candidate + legend · city labels (`places`) · (if time) perimeters dashed grey · (finish early) click popup `name` · (finish early) `fill-extrusion` on `buildings_auburn` 👀
⏱ stuck past minute 8 → paste `steps/step3-styled.json`

🎯 Very High solid red · water blue · 10 shelters (1 filled) · Mosquito perimeter dashed · attribution visible

---

<!-- S26 · after the hands-on · ~1 min + Maputnik 60 s -->
<!-- Say: "Compare yours with the prebuilt file. Two road datasets, so a small misalignment is expected — that's fine, and worth noticing." -->

# After the hands-on: yours vs prebuilt

- Load `data/prebuilt/evac.pmtiles` next to `out/evac.pmtiles` — same layers?
- **Maputnik, 60 s** (instructor): the same tiles in a visual style editor, served via `pmtiles serve`
- **Expect small misalignment:** two road datasets (yours vs the prebuilt reference) won't line up exactly

<div class="warn">Hazard edges are zone boundaries, not a guarantee: a road just outside a polygon is not "safe".</div>

Next: **Phase 3c** — routes on top of this map.
