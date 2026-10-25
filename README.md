# Routes to Safety — a wildfire-evacuation map from open data

Hands-on workshop for **FOSS4G North America 2026** · Sacramento, CA · Mon Nov 2, 2026 · room Beavis.
You build an evacuation map for the **Placer County I-80 corridor** from open data and open tools, then ask it:
*which shelter can I reach by road, and how long does it take if I-80 is closed?*

**Finished result:** <https://vishal4c.github.io/routes-to-safety-workshop/demo/>

<img src="docs/img/demo-walkthrough.gif" width="100%" alt="Drop a pin, get the nearest shelter by road, close I-80, switch between the Fire evac map, the Base map and the Shelter reach view"/>

> **Teaching example, not an official evacuation resource.** Drive-time estimates assume no traffic and no closures.
> In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.

## Five phases

```mermaid
flowchart LR
  classDef ph   fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef out  fill:#FEE3D8,stroke:#FF6101,color:#161D26

  P0["Phase 0 · Setup<br/>Codespaces / Docker / native<br/><code>setup/</code>"]:::ph
  P1["Phase 1 · Data prep<br/>DuckDB over Overture + CAL FIRE<br/><code>00-data/</code>"]:::ph
  P2["Phase 2 · Map artifacts<br/>Planetiler · OSRM · reach bands<br/><code>01-tiles/</code> <code>scripts/</code>"]:::ph
  P3["Phase 3 · Application<br/>MapLibre, three views + routing<br/><code>02-web/</code> <code>03-routing/</code> <code>demo/</code>"]:::ph
  P4["Phase 4 · Adapt<br/>your own community<br/><code>04-adapt/</code>"]:::ph
  A1[/"out/*.geojson"/]:::file
  A2[/"evac.pmtiles<br/>OSRM graph<br/>coverage_bands.geojson"/]:::file
  A3(["Fire evac map · Base map · Shelter reach<br/>+ nearest shelter by road"]):::out

  P0 --> P1 --> A1 --> P2 --> A2 --> P3 --> A3
  P3 --> P4
```

| Phase | Name | Steps | Folder |
|---|---|---|---|
| 0 | Setup | pick Codespaces / Docker / native · checkpoint line | [`setup/`](setup/) |
| 1 | Data prep | 1a explore · 1b shelters × hazard · 1c export | [`00-data/`](00-data/) |
| 2 | Map artifacts | 2a tiles · 2b routing graph · 2c reach rings | [`01-tiles/`](01-tiles/) · [`scripts/`](scripts/) |
| 3 | Application | 3a style · 3b three views · 3c routing · 3d finished app | [`02-web/`](02-web/) · [`03-routing/`](03-routing/) · [`demo/`](demo/) |
| 4 | Adapt | one bbox → rerun | [`04-adapt/`](04-adapt/) |

Always run commands from the **repo root**.

## Phase 0 — Setup · pick one way to run

```mermaid
flowchart LR
  classDef step fill:#FFFFFF,stroke:#8A939B,color:#161D26
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26
  classDef tool fill:#161D26,stroke:#161D26,color:#FFFFFF

  A["A · Codespaces<br/>nothing to install"]:::tool
  B["B · Docker image<br/>laptop, same container"]:::tool
  C["C · Native tools<br/>no routing"]:::step
  L0(["Phase 0 checkpoint<br/>duckdb -c &quot;.read setup/hello-geo.sql&quot;"]):::chk
  A --> L0
  B --> L0
  C --> L0
```

### A — GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/vishal4c/routes-to-safety-workshop?quickstart=1)

Or: repository page → green **Code** button → **Codespaces** → **Create codespace on main** (personal GitHub account, free tier is enough).
Three containers start (tool shell, OSRM, Caddy) and the 150 MB data bundle downloads; you land in a terminal with `setup/check_setup.py` already run.
Open the map: **Ports** tab → port **8080** → globe icon. Never forward port 5000; routing is `/osrm` on port 8080.

### B — Docker image on your laptop

Image: **`ghcr.io/vishal4c/routes-to-safety-workshop:latest`** (amd64 + arm64: DuckDB 2.0.0 + spatial, Temurin 21, Planetiler 0.10.2, go-pmtiles 1.31.2, Node 22, osmium-tool, uv).
Needs a container runtime — Docker Desktop, Finch (`finch vm init` once), OrbStack, Colima or Podman; swap `docker` for `finch`/`podman`.

```bash
git clone --depth 1 https://github.com/vishal4c/routes-to-safety-workshop.git
cd routes-to-safety-workshop
docker compose pull            # tool image · OSRM · Caddy  (≈ 1 GB, once)
docker compose up -d
docker compose exec workshop bash
bash scripts/get-bundle.sh     # first time: prebuilt tiles, routing graph, OSM extracts (150 MB, checksum-verified)
python3 setup/check_setup.py
```

<img src="docs/img/check-setup.png" width="85%" alt="check_setup.py inside the workshop container: all checks OK, tier 2, OSRM reachable via Caddy"/>

| What | Where |
|---|---|
| The repo folder | bind-mounted at `/workspaces/routes-to-safety-workshop` — files you write appear on the laptop and are served at once |
| Map and hands-on pages | <http://localhost:8080/02-web/> (Caddy answers Range requests, which PMTiles needs) |
| OSRM | browser: same-origin `/osrm/…` · container shell: `$OSRM_URL` = `http://caddy:8080/osrm` |
| Stop / restart | `docker compose down` · `docker compose up -d` |
| Offline room | `BUNDLE_ZIP=/path/data-bundle.zip bash scripts/get-bundle.sh` |

The tool container cannot *build* an OSRM graph (no Docker inside); the graph ships in the bundle, and for your own town you run `scripts/build-osrm.sh` on the laptop (Phase 4).

### C — native tools

Install Git, DuckDB CLI 2.0.0, Temurin 21, Node 22, uv, go-pmtiles ([per-OS commands](setup/README.md#tier-3--native-no-containers-no-routing)), then:

```bash
git clone --depth 1 https://github.com/vishal4c/routes-to-safety-workshop.git && cd routes-to-safety-workshop
bash scripts/get-bundle.sh       # run this before check_setup (150 MB, checksum-verified)
python3 setup/check_setup.py     # the OSRM and web-server lines are red here — expected without containers
npx serve -l 8080 .              # never `python -m http.server` (no Range support → blank map); another port is fine, swap it in every URL below
export WEB_URL=http://localhost:8080             # in a second terminal; the checks below use it
```
No routing without containers (OSRM has no Windows/macOS binary). Have Docker anyway? `docker compose up -d osrm caddy` serves the repo on :8080 **and** adds routing — skip `npx serve`, and `export OSRM_URL=http://localhost:8080/osrm`. Otherwise pair up for Phase 3c.

**Where to type.** Options A and B: every command in this README runs in the **tool container shell** — the terminal Codespaces opens, or `docker compose exec workshop bash` (prompt `vscode ➜ /workspaces/routes-to-safety-workshop`). It has every tool, and `$WEB_URL` (`http://caddy:8080`) and `$OSRM_URL` (`http://caddy:8080/osrm`) are preset there; `localhost` inside it is the container itself, not Caddy. Your browser reaches the same server at `http://localhost:8080`. The only commands that run in a **laptop terminal** (your own shell, in the clone folder) are `docker compose …` and `scripts/build-osrm.sh` — both marked below. Option C: everything is the laptop terminal, with the two variables exported as above.

### Phase 0 — setup checkpoint

```bash
duckdb -c ".read setup/hello-geo.sql"
```
```
OK — DuckDB 2.0.0 · 10 shelters (1 verified, 9 candidate) · nearest to Colfax (crow-flies): Sierra Vista Community Center, 0.2 km
```
Same line on every screen → ready. Still red after the fixes it prints → switch option (`check_setup.py` calls them tiers 1–3), or follow along on the demo site.

---

## Phase 1 — Data prep · [`00-data/`](00-data/)

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef tool fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef step fill:#FFFFFF,stroke:#8A939B,color:#161D26
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26

  OV[/"data/overture/*.parquet<br/>segments · places · water<br/>buildings · localities"/]:::file
  HZ[/"data/hazard/<br/>FHSZ · fire perimeters"/]:::file
  D["DuckDB 2.0 + spatial"]:::tool
  S1["1a · explore<br/>01-explore.sql"]:::step
  S2["1b · shelters × hazard<br/>02-shelters.sql"]:::step
  S3["1c · export<br/>03-export.sql"]:::step
  O(["out/*.geojson<br/>roads = 36,294"]):::chk
  OV --> D
  HZ --> D
  D --> S1 --> S2 --> S3 --> O
```

```bash
duckdb -c ".read 00-data/01-explore.sql"      # schema · drivable roads by class (sum 36,294) · top place categories
duckdb -c ".read 00-data/02-shelters.sql"     # 10 candidate shelters, each tagged with its FHSZ class
duckdb -c ".read 00-data/03-export.sql"       # prints nothing; `ls out/` → 8 GeoJSON files
duckdb -c "LOAD spatial; SELECT count(*) FROM ST_Read('out/roads.geojson')"      # → 36294
```

Expected from 1b — three of the ten candidate shelters sit inside a *Very High* zone:
```
│ Colfax High School            │ candidate │ school           │ Very High        │
│ Georgetown School             │ candidate │ school           │ Very High        │
│ Sierra Vista Community Center │ candidate │ community_center │ Very High        │
```

Behind? `cp data/prebuilt/out/* out/`. Optional extra SQL: [`00-data/exercises.md`](00-data/exercises.md).

---

## Phase 2 — Map artifacts · [`01-tiles/`](01-tiles/) · [`scripts/`](scripts/)

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef tool fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26

  GJ[/"out/*.geojson"/]:::file
  PT["2a · Planetiler<br/>01-tiles/evac.yml"]:::tool
  PM(["out/evac.pmtiles<br/>8 layers · z4–14 · ≈ 7 MB"]):::chk
  PBF[/"data/osm/study-area.osm.pbf"/]:::file
  OS["2b · OSRM<br/>extract → partition → customize"]:::tool
  GR(["data/osrm/study-area.osrm.*<br/>served at /osrm"]):::chk
  H3["2c · make-coverage.py<br/>H3 cells → OSRM /table"]:::tool
  CB(["data/coverage/coverage_bands.geojson<br/>10 / 20 / 30 min per shelter"]):::chk
  GJ --> PT --> PM
  PBF --> OS --> GR --> H3 --> CB
```

**2a · Tiles**
```bash
01-tiles/build.sh                                   # java -jar planetiler.jar generate-custom --schema=01-tiles/evac.yml … (about 4 s)
pmtiles show out/evac.pmtiles                       # 8 vector layers, min zoom 4, max zoom 14, 1607 tiles
curl -sSI -H "Range: bytes=0-15" "$WEB_URL/out/evac.pmtiles" | head -1     # HTTP/1.1 206 Partial Content — anything else means the wrong server
```
No GeoJSON yet? `01-tiles/build.sh --prebuilt`.

**2b · Routing graph** — already in the bundle and served by the `osrm` container:
```bash
curl "$OSRM_URL/nearest/v1/driving/-121.08,38.90"     # → {"code":"Ok", …}  the graph answers
```
Optional — watch a graph being built on a tiny clip. **Laptop terminal**, in the clone folder (needs Docker/Finch; the tool container has no Docker inside it):
```bash
scripts/build-osrm.sh data/osm/colfax.osm.pbf out/osrm     # about 1 min → out/osrm/colfax.osrm.*
```

**2c · Reach bands** — drive time from every road-bearing H3 cell (res 8, 3,341 cells) to all 10 shelters, dissolved into non-overlapping 0–10 / 10–20 / 20–30-minute rings per shelter:
```bash
scripts/make-coverage.py --osrm http://osrm:5000      # about 4 s · overwrites data/coverage/*.geojson · run as written (uv shebang) · Option C: --osrm $OSRM_URL
```

---

## Phase 3 — Application · [`02-web/`](02-web/) · [`03-routing/`](03-routing/) · [`demo/`](demo/)

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef step fill:#FFFFFF,stroke:#8A939B,color:#161D26
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26
  classDef out  fill:#FEE3D8,stroke:#FF6101,color:#161D26

  PM[/"out/evac.pmtiles<br/>coverage_bands.geojson"/]:::file
  S["3a · style<br/>Edit → Add tiles, then steps 1–4"]:::step
  V(["3b · three views<br/>Fire evac map · Base map · Shelter reach"]):::chk
  R["3c · routing<br/>/table → argmin → /route<br/>you write 6 lines"]:::step
  I80["I-80 closed<br/>exclude=motorway"]:::step
  D(["3d · demo/<br/>the finished app"]):::out
  PM --> S --> V --> R --> I80 --> D
```

Open <http://localhost:8080/02-web/> (Codespaces: Ports → 8080 → globe → add `/02-web/`). The **Fire evac map is blank**: nothing is plugged in yet, not even the tiles. Nothing in this phase needs a file edit — the **Edit** button (top-left, next to the view buttons) opens a panel with one row per dataset; each row has an **Add** button. Whatever you plug in stays in the browser's memory until you reload the page.

**3a · Style** — Fire evac map view → **Edit** → click **Add**, top to bottom:

| Row | What appears |
|---|---|
| 0 · Tiles (`out/evac.pmtiles`, built in 2a) | nothing visible yet — the tiles are now the map's data source, and rows 1–4 unlock. No `out/evac.pmtiles`? It falls back to `data/prebuilt/evac.pmtiles` and says so |
| 1 · Roads (`steps/step1-roads.json`) | grey road network |
| 2 · Hazard zones, water, land cover, shelters, town labels (`step2-hazard-water.json`) | the map now matches the legend: Moderate / High / Very High fill, water, shelters (filled = verified, hollow = candidate), labels |
| 3 · Past fire perimeters (`step3-styled.json`) | dashed Mosquito 2022 / River 2021 outlines |
| 4 · 3D buildings over Auburn (`step4-final.json`, finish early) | zoom past 13 over Auburn, right-drag to tilt |

Rows 1–4 are each one JSON file of MapLibre layers drawn from the tiles. To restyle: open the file, change a colour or a width, click the row's **Reload**. Rebuilt the tiles in 2a? **Reload** row 0 and the layers you already added redraw on the new tiles. Order never matters; the attribution bottom-right is always on (the licences require it). Lost? `02-web/solution.html` is the page with everything plugged in.

**3b · Three views, one at a time** — the buttons top-left: **Fire evac map** (what you just styled) · **Base map** (OpenStreetMap raster, needs internet; nothing to plug in) · **Shelter reach** → **Edit** → **Add** the tiles and roads if you have not yet, then the reach rings (`data/coverage/coverage_bands.geojson`, the Phase 2c output: ≤ 10 min green · ≤ 20 blue · ≤ 30 light red; click a shelter for its reach only). The legend follows the view; nothing is drawn on top of anything else.

<img src="docs/img/view-evac.jpg" width="85%" alt="Fire evac map with all four datasets plugged in: hazard classes, perimeters, labels, shelters"/>

**3c · Routing** — in any view's Edit panel, the last row **Routing** plugs in the finished router ([`03-routing/route.js`](03-routing/route.js)): click the map → nearest shelter **by road**, drag the pin to recompute, tick **I-80 closed** (`&exclude=motorway` on both calls). What it calls:

```bash
curl "$OSRM_URL/nearest/v1/driving/-121.08,38.90"                                   # snap a point  → {"code":"Ok",…}
curl "$OSRM_URL/table/v1/driving/-120.8182,39.0199;-121.0768,38.8971?sources=0"     # seconds pin → shelter
```
Want to write it yourself? Skip the Routing row and uncomment one `import(…)` line at the end of `02-web/index.html`: `steps/step1-route.js` (one hard-coded `/route`, Foresthill → Placer High, console `Route: 35.8 min, 31.8 km`) or `steps/step2-scaffold.js` (you fill the 6 lines: `/table` → drop `durations[0][0]` → argmin → `/route` → `setData` → popup; answer in `steps/step3-solution.js`).

<img src="docs/img/route-foresthill.jpg" width="85%" alt="Foresthill pin, route to Placer High School, 36 min"/>

Nearest on the map ≠ nearest by road: from Foresthill, Georgetown School is 12.4 km away but 59.7 min by road; Placer High is 35.8 min. From Dutch Flat with I-80 closed, Sierra Vista CC stays nearest but 17.9 → **31.3 min** via Dutch Flat Rd / Rollins Lake Rd.

> A real closure is not a URL parameter. This is the calculation, not detection; shelter status, traffic, smoke and capacity are not in the data.

**3d · The finished app** — [`demo/`](demo/): the same three views + the router with a small side panel (view switch, legend, I-80 toggle, result). Static files only; routing via your Caddy `/osrm` locally, the public OSRM server on GitHub Pages.

<img src="docs/img/demo-app.jpg" width="85%" alt="demo app: Fire evac map view with a pin and the route to the nearest shelter"/>

<http://localhost:8080/demo/> · URL state: `?lng=&lat=&closed=1&view=reach&shelter=placer-high`

---

## Phase 4 — Adapt the pipeline to your community · [`04-adapt/`](04-adapt/)

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef tool fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef step fill:#FFFFFF,stroke:#8A939B,color:#161D26
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26

  VE[/"versions.env<br/>BBOX_W/S/E/N · OSM_EXTRACT_URL"/]:::file
  PL["make-data.sh --plan<br/>no network"]:::step
  FE["make-data.sh<br/>overture · hazard · osm · exports"]:::tool
  SH[/"data/shelters.geojson<br/>your list, all candidate"/]:::file
  RB["rebuild<br/>build.sh · build-osrm.sh · make-coverage.py"]:::tool
  OK(["your town, same three views"]):::chk
  VE --> PL --> FE --> RB --> OK
  SH --> RB
```

```bash
# 1. box around your community (bboxfinder.com, keep it under ~0.5 sq. degrees) → the four BBOX_* lines in versions.env
scripts/make-data.sh --plan                      # 2. prints every query, file and size estimate — downloads nothing
scripts/make-data.sh                             # 3. fetch: overture · hazard · osm · exports  (Geofabrik extract is the big one)
#    4. replace data/shelters.geojson (id, name, status, type, town, source) — mark everything candidate until confirmed
#    5. hazard outside California: swap the source, keep the SQL + style → 04-adapt/README.md#swap-the-hazard
duckdb -c ".read 00-data/03-export.sql"          # 6. rebuild artifacts
01-tiles/build.sh
scripts/build-osrm.sh                            #    laptop terminal (Docker/Finch), then: docker compose restart osrm
scripts/make-coverage.py --osrm http://osrm:5000
#    7. center/zoom in 02-web/index.html and demo/app.js, default pin in 03-routing/route.js
sha256sum -c data/CHECKSUMS.sha256               # 8. verify, then publish out/evac.pmtiles + data/coverage/ + 02-web/ + demo/ to any static host
```

Laptop → planet: same shapes, bigger inputs — [`04-adapt/README.md`](04-adapt/README.md#laptop--planet).

---

## Stop everything

**Laptop terminal**, in the clone folder:
```bash
docker compose down              # stops and removes the three containers; images stay cached (`docker compose up -d` brings it back in seconds)
docker compose down --rmi all    # the same, plus delete the 3 GB of images
```
Option C: `Ctrl-C` in the `npx serve` terminal. Something still holding :8080? `lsof -nP -iTCP:8080 -sTCP:LISTEN` (Windows: `netstat -ano | findstr :8080`), then `kill <PID>`.
Codespaces: <https://github.com/codespaces> → … → **Stop codespace** (it also stops itself after 30 idle minutes).

## The stack (pinned in [`versions.env`](versions.env))

| Tool | Version | | Tool | Version |
|---|---|---|---|---|
| DuckDB CLI + spatial | 2.0.0 | | MapLibre GL JS | 6.14.0 |
| Temurin / OpenJDK | 21 | | PMTiles (JS) | 4.5.0 |
| Planetiler | v0.10.2 | | Node | 22 |
| go-pmtiles | v1.31.2 | | osmium-tool | 1.19 |
| OSRM | `ghcr.io/project-osrm/osrm-backend:v26.10.0-debian` | | Overture Maps release | 2026-09-23.1 |
| Tool image | `ghcr.io/vishal4c/routes-to-safety-workshop:latest` | | Caddy | `caddy:2-alpine` |

`scripts/check-versions.sh` fails CI if any file drifts from `versions.env`.

## Study area

**Placer County I-80 corridor: Rocklin → Auburn → Colfax → Foresthill.** Bounding box (W,S,E,N) **-121.40, 38.72, -120.52, 39.20**.
River Fire (2021) evacuated Colfax; the Mosquito Fire (2022, 76,771 acres) moved the shelter to Sierra College mid-incident; CAL FIRE's Very High zone rings Auburn and Colfax; I-80 is the lifeline.

## Licensing and attribution

- **Code** (scripts, config, JS): [MIT](LICENSE) · **Materials** (slides, docs, exercises): [CC BY-SA 4.0](LICENSE-materials) ·
  **Data** keeps its source licences: [`data/LICENSE-data.md`](data/LICENSE-data.md); provenance: [`data/README.md`](data/README.md).
- Keep this line on every map: **© OpenStreetMap contributors · © Overture Maps Foundation · Fire Hazard Severity Zones: CAL FIRE FRAP (CC-BY) · Land cover: ESA WorldCover (CC-BY)**.

Slides: [`slides/`](slides/) · instructor material: [`instructor/`](instructor/).

## Instructors

**Vishal Kumar** · **Shaishav Maisuria** — Amazon Maps. The workshop teaches only the public open stack.
