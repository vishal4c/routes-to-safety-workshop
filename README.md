# Routes to Safety — an evacuation-services map from open geospatial data

Hands-on workshop for **FOSS4G North America 2026** · Sacramento, CA · Mon Nov 2, 2026 · room Beavis.

In this workshop we will build an **evacuation-services map** for the **Placer County I-80 corridor** — shelters, fire-hazard zones and the roads that connect them — and use it to answer a route-based question: *which shelter can I reach by road, and how long does it take if I-80 is closed?* In the last phase we point the same pipeline at a community of our choice.

**Tech stack we will use**

| | Topic | Hands-on with |
|---|---|---|
| 1 | **Open geospatial datasets** — what is in OpenStreetMap, the Overture Maps themes (transportation, places, divisions, base, buildings) and public hazard layers (CAL FIRE); how to pull a study area out of a planet-wide release in seconds, and how to read and write GeoJSON with SQL | DuckDB + spatial |
| 2 | **Tile generation** — turning GeoJSON into vector tiles, and serving the whole map as one static file with no tile server | Planetiler · PMTiles |
| 3 | **Routing engines for route-based analysis** — building a routing graph from an OpenStreetMap extract, then `/nearest`, `/table` and `/route` for nearest-shelter-by-road, drive-time reach bands (isochrones) and what-if closures | OSRM |
| 4 | **Rendering** — a MapLibre style, three views over the same tiles, and routing wired into the page | MapLibre GL JS |

**Finished result:** <https://vishal4c.github.io/routes-to-safety-workshop/demo/>

<img src="docs/img/demo-walkthrough.gif" width="100%" alt="Drop a pin, get the nearest shelter by road, close I-80, switch between the Fire evac map, the Base map and the Shelter reach view"/>

> **Teaching example, not an official evacuation resource.** Drive-time estimates assume no traffic and no closures.
> In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.

## What we will build — five phases

```mermaid
flowchart LR
  classDef ph   fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef out  fill:#FEE3D8,stroke:#FF6101,color:#161D26

  P0["Phase 0 · Setup<br/>Codespaces / Docker / native"]:::ph
  P1["Phase 1 · Data prep<br/>fetch → DuckDB over data/"]:::ph
  P2["Phase 2 · Map artifacts<br/>tiles · routing graph · reach bands"]:::ph
  P3["Phase 3 · Application<br/>MapLibre, three views + routing"]:::ph
  P4["Phase 4 · Adapt<br/>a community of our choice"]:::ph
  D[/"data/overture/*.geojson<br/>data/hazard/*.geojson<br/>data/shelters.geojson"/]:::file
  A2[/"out/evac.pmtiles<br/>data/osrm/*<br/>data/coverage/coverage_bands.geojson"/]:::file
  A3(["Fire evac map · Base map · Shelter reach<br/>+ nearest shelter by road"]):::out

  P0 --> P1 --> P2 --> A2 --> P3 --> A3
  D --> P1
  D --> P2
  P3 --> P4
```

| Phase | Steps | We end up with |
|---|---|---|
| 0 Setup | pick Codespaces / Docker / native · one checkpoint line | a shell with every tool, a web server on :8080 |
| 1 Data prep | Fetch · 1a look around · 1b shelters × hazard · 1c export | we can read and write GeoJSON with SQL |
| 2 Map artifacts | 2a tiles · 2b routing graph · 2c reach bands | the **three files** the app needs |
| 3 Application | 3a style · 3b shelter reach · 3c routing · 3d finished app | the map, three views, nearest shelter by road |
| 4 Adapt | one box → the same steps for a community of our choice | our town, same three views |

**This page is the whole workshop.** Every command is here, in order; folders are listed in the [repository map](#repository-map) at the end. Blocks that start with **▸ Optional** open on click and can be skipped on the day. Every command runs from the **repo root**, and every block is labelled with where to paste it (💻 laptop terminal · 🐳 container shell · 🌐 browser — legend in Phase 0).

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

| | For | Routing | Works without wifi |
|---|---|---|---|
| **A** Codespaces | no Docker on the laptop, corporate laptop | yes | no |
| **B** Docker image — *recommended wherever containers can run* | wants everything local | yes | yes* |
| **C** Native tools | containers blocked | **no** (pair with a neighbour) | yes* |

\* Data, tiles and routing are all local, except Phase 1 · Fetch (S3 + CAL FIRE) — offline: `scripts/stage-data.sh`. The other exception is the map page itself: it loads the MapLibre and PMTiles JavaScript libraries from unpkg.com, so the first page load needs a connection (the browser caches them afterwards).

`setup/check_setup.py` calls these tiers 1, 2 and 3. Browser only? <https://vishal4c.github.io/routes-to-safety-workshop/> has the slides, the demo and the map page (no routing, nothing to install).

### A — GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/vishal4c/routes-to-safety-workshop?quickstart=1)

Or: repository page → green **Code** button → **Codespaces** → **Create codespace on main**. Use a **personal** GitHub account (employer-managed accounts often block Codespaces); the free tier is enough.
Three containers start (tool shell, OSRM, Caddy — the same images as option B, pulled; Codespaces adds one small layer for its Docker helper), the 143 MB data bundle downloads and `setup/check_setup.py` runs automatically. After 3–5 minutes we land in a terminal: that terminal is our 🐳 **container shell** (it also runs the 💻 `docker` commands).
Open the map: **Ports** tab → row **8080** → globe icon. Never type `localhost:8080` into the laptop's own browser there, and **never forward port 5000** — routing is `/osrm` on port 8080. Smoke test: `docker ps` lists three containers.

### B — Docker image on the laptop

Image: **`ghcr.io/vishal4c/routes-to-safety-workshop:latest`** (amd64 + arm64: DuckDB 2.0.0 + spatial, Temurin 21, Planetiler 0.10.2, go-pmtiles 1.31.2, Node 22, osmium-tool, uv).
Needs a container runtime: **Finch** (`brew install --cask finch` or `winget install Amazon.Finch`, then `finch vm init` once — recommended on corporate laptops; type `finch compose` wherever this page says `docker compose`), Docker Desktop, OrbStack, Colima or Podman. The scripts auto-detect `docker → finch → podman → nerdctl`. Docker Desktop and OrbStack include **Compose**; a Homebrew `docker` CLI with Colima does not (▸ box below).

> [!TIP]
> **Where to paste.** Every block is labelled. 💻 **Laptop terminal** is the terminal app on the laptop. 🐳 **Container shell** is the window whose prompt starts with `vscode ➜`. Copy a block with its copy button (top-right) and paste it whole — the blocks hold commands only.

**Step 1 of 4 · Check Docker** · 💻 Laptop terminal
```bash
docker info --format '{{.ServerVersion}}'
docker compose version
```
✅ Two version numbers.

❌ `unknown command: docker compose`, `unknown shorthand flag: 'd' in -d` or `Cannot connect to the Docker daemon` → **▸ No Docker Compose?** below, then this step again.

**Step 2 of 4 · Download the workshop and start it** · 💻 Laptop terminal · ≈ 1 GB the first time
```bash
git clone --depth 1 https://github.com/vishal4c/routes-to-safety-workshop.git
cd routes-to-safety-workshop
docker compose pull
docker compose up -d
docker compose ps
```
✅ The last command lists `caddy`, `osrm` and `workshop`, all running. OSRM waits until the routing graph arrives in step 3.

**Step 3 of 4 · Get the data bundle and check the setup** · 💻 Laptop terminal (it runs inside the container for us) · 143 MB
```bash
docker compose exec workshop bash -c 'bash scripts/get-bundle.sh && sleep 10 && python3 setup/check_setup.py'
```
✅ Ends with tier `2 (local containers)` and `ALL REQUIRED CHECKS PASSED`. The pause lets OSRM load the graph that just arrived.

**Step 4 of 4 · Step into the container** · 💻 Laptop terminal
```bash
docker compose exec workshop bash
```
✅ The prompt changes to `vscode ➜ /workspaces/routes-to-safety-workshop`. This window is our 🐳 **Container shell** from here on; a second tab stays on the laptop for 💻 blocks (start, stop, restart).

<details><summary><b>▸ No Docker Compose?</b> macOS with Colima or a Homebrew <code>docker</code> · 💻 Laptop terminal</summary>

```bash
brew install colima docker-compose
mkdir -p ~/.docker/cli-plugins
ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" ~/.docker/cli-plugins/docker-compose
colima start --cpu 4 --memory 4
docker compose version
```
✅ `Docker Compose version …`. The first `colima start` downloads a VM image (a few minutes); after a reboot, run `colima start` before any `docker compose`.

</details>

<img src="docs/img/check-setup.png" width="85%" alt="check_setup.py inside the workshop container: all checks OK, tier 2, OSRM reachable via Caddy"/>

| What | Where |
|---|---|
| The repo folder | bind-mounted at `/workspaces/routes-to-safety-workshop` — files written there appear on the laptop and are served at once |
| Map and hands-on pages | <http://localhost:8080/02-web/> (Caddy answers Range requests, which PMTiles needs) |
| OSRM | browser: same-origin `/osrm/…` · container shell: `$OSRM_URL` = `http://caddy:8080/osrm` |
| Stop / restart | `docker compose down` · `docker compose up -d` |
| Offline room | `BUNDLE_ZIP=/path/data-bundle.zip bash scripts/get-bundle.sh` · Phase 1: `scripts/stage-data.sh` |

### C — native tools

Install Git, DuckDB CLI 2.0.0, Temurin 21, Node 22, uv and go-pmtiles (▸ box below), then:

💻 Laptop terminal · 143 MB, checksum-verified
```bash
git clone --depth 1 https://github.com/vishal4c/routes-to-safety-workshop.git && cd routes-to-safety-workshop
bash scripts/get-bundle.sh
python3 setup/check_setup.py
npx serve -l 8080 .
```
✅ `check_setup.py` passes with the OSRM and web-server lines red (expected without containers), then `serve` keeps running on :8080. Never `python -m http.server` (no Range support → blank map); another port is fine, swap it in every URL.

💻 Laptop terminal · a second tab, in the clone folder (the checks below use it)
```bash
export WEB_URL=http://localhost:8080
```
✅ No output. In option C every 🐳 block on this page goes in this laptop terminal.

No routing without containers (OSRM has no Windows/macOS binary). Have Docker anyway? `docker compose up -d osrm caddy` serves the repo on :8080 **and** adds routing — skip `npx serve`, and `export OSRM_URL=http://localhost:8080/osrm`.

<details><summary><b>▸ Install commands per OS</b> (option C)</summary>

**macOS (Homebrew)** · 💻 Laptop terminal · macOS
```bash
brew install duckdb
brew install --cask temurin@21
brew install node@22
brew install uv
brew install pmtiles
```
✅ `duckdb --version` → v2.0.0. `brew install node` also works for Node. `pmtiles` here is go-pmtiles — **not** `pip/conda install pmtiles`.
**Windows (winget, then use Git Bash)** · 💻 Laptop terminal · Windows PowerShell
```powershell
winget install Git.Git
winget install DuckDB.cli
winget install EclipseAdoptium.Temurin.21.JDK
winget install OpenJS.NodeJS.LTS
winget install astral-sh.uv
```
go-pmtiles: download `go-pmtiles_1.31.2_Windows_x86_64.zip` from <https://github.com/protomaps/go-pmtiles/releases/tag/v1.31.2> and unzip `pmtiles.exe` into a folder on PATH, e.g. `%USERPROFILE%\bin`.

✅ `duckdb --version` → v2.0.0. Close and reopen Git Bash afterwards so PATH refreshes. If `duckdb` is older than 2.0.0, download `duckdb-cli-windows-amd64.tar.gz` from the DuckDB v2.0.0 release page instead.

**Linux (Debian/Ubuntu)** · 💻 Laptop terminal · Linux
```bash
sudo apt update && sudo apt install -y curl unzip git python3 osmium-tool
sudo mkdir -p /etc/apt/keyrings && curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release; echo $VERSION_CODENAME) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update && sudo apt install -y temurin-21-jdk
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs
curl -fsSL https://github.com/duckdb/duckdb/releases/download/v2.0.0/duckdb-cli-linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin duckdb
curl -fsSL https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Linux_x86_64.tar.gz | sudo tar -xz -C /usr/local/bin pmtiles
curl -LsSf https://astral.sh/uv/install.sh | sh
```
On ARM, swap `amd64` for `arm64` in the DuckDB URL (and `x86_64` for `arm64` in the go-pmtiles one).

✅ `duckdb --version` → v2.0.0, `java -version` → 21.

Alternative: `pixi install && pixi shell` (`pixi.toml`) gives DuckDB, Java 21, Node, osmium, uv — but **no pmtiles** (the conda-forge package of that name is a Python library); install the go-pmtiles binary as above.

**Windows: Git Bash → PowerShell** — use Git Bash where possible. If PowerShell is the only option:

| Git Bash | PowerShell |
|---|---|
| `bash scripts/get-bundle.sh` | `powershell -ExecutionPolicy Bypass -File scripts\get-bundle.ps1` |
| `bash scripts/stage-data.sh` | `Copy-Item staged_data\overture\*.geojson data\overture\; Copy-Item staged_data\hazard\*.geojson data\hazard\` |
| `scripts/fetch-overture.sh` · `scripts/fetch-hazard.sh` | no PowerShell version — Git Bash only (or `stage-data` above) |
| `01-tiles/build.sh` | `powershell -ExecutionPolicy Bypass -File 01-tiles\build.ps1` |
| `python3 setup/check_setup.py` | `python setup\check_setup.py` |
| `duckdb -c ".read 00-data/01-explore.sql"` | same |
| `ls out/` · `cat file` · `cp a b` | `Get-ChildItem out\` · `Get-Content file` · `Copy-Item a b` (the aliases `ls`, `cat`, `cp` also work) |
| `export VAR=value` | `$env:VAR = "value"` |
| `curl -s URL` | `curl.exe -s URL` (plain `curl` is an alias for Invoke-WebRequest) |
| `sha256sum file` | `Get-FileHash file -Algorithm SHA256` |
| `java …`, `pmtiles …`, `npx serve -l 8080 .`, `docker compose up -d` | same |

</details>

### Where to paste — the three labels

| Label | Where |
|---|---|
| 💻 **Laptop terminal** | the terminal app on the laptop, in the clone folder |
| 🐳 **Container shell** | the tool container: prompt `vscode ➜ /workspaces/routes-to-safety-workshop`. `$WEB_URL` and `$OSRM_URL` are preset there; `localhost` inside it is the container itself |
| 🌐 **Browser** | `http://localhost:8080/…` (Codespaces: Ports → 8080 → globe) |

- **Where am I?** A prompt starting with `vscode ➜` is the container; anything else is the laptop. Keep two terminal tabs open: one laptop, one container.
- **Codespaces:** its one terminal is the 🐳 container shell and also runs the 💻 `docker` commands.
- **Option C:** there is no container — 🐳 blocks go in the laptop terminal.
- **macOS zsh:** every block is comment-free, so it pastes as is. For anything else with `# notes`, run `setopt interactivecomments` first.
- ✏️ marks a value to change before pasting, or a file to edit instead of a terminal paste.
- Always from the **repo root** (the folder with `versions.env`).

### Phase 0 checkpoint

🐳 Container shell
```bash
duckdb -c ".read setup/hello-geo.sql"
```
✅ We should see
```text
OK — DuckDB 2.0.0 · 10 shelters (1 verified, 9 candidate) · nearest to Colfax (crow-flies): Sierra Vista Community Center, 0.2 km
```
Same line on every screen → ready.

❌ Still red after the fixes `check_setup.py` prints → switch option, or follow along on the demo site.

More to try while others catch up: [`setup/exercises.md`](setup/exercises.md) (**A** shelters per status · **B** nearest shelter to Auburn · **C** tool versions against the pins · **D** OSRM's nearest road).

---

## Phase 1 — Data prep · look at the data with SQL

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef tool fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef step fill:#FFFFFF,stroke:#8A939B,color:#161D26
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26

  SRC[/"Overture S3 · CAL FIRE"/]:::file
  F["Fetch<br/>fetch-overture.sh · fetch-hazard.sh"]:::tool
  ST[/"staged_data/<br/>committed copy"/]:::file
  SD["stage-data.sh<br/>offline"]:::step
  OV[/"data/overture/*.geojson<br/>roads · water · towns · land cover<br/>buildings · places"/]:::file
  HZ[/"data/hazard/*.geojson<br/>FHSZ · fire perimeters"/]:::file
  D["DuckDB 2.0 + spatial"]:::tool
  S1["1a · look around<br/>01-explore.sql"]:::step
  S2["1b · shelters × hazard<br/>02-shelters.sql"]:::step
  S3["1c · export<br/>03-export.sql"]:::step
  O(["out/shelter-candidates.geojson<br/>95 places"]):::chk
  SRC --> F
  F --> OV
  F --> HZ
  ST -.-> SD
  SD -.-> OV
  SD -.-> HZ
  OV --> D
  HZ --> D
  D --> S1 --> S2 --> S3 --> O
```

**Fetch · pull our study area out of the open releases** · 🐳 Container shell (Windows option C: Git Bash)
```bash
scripts/fetch-overture.sh
scripts/fetch-hazard.sh
```
About a minute on decent wifi: six Overture themes from S3 (≈ 25–60 s), then two CAL FIRE layers (≈ 8 s). Each script checks its counts against the table below.

✅ Eight files in `data/overture/` and `data/hazard/`, with the counts in the table below.

❌ No wifi, slow S3 or CAL FIRE down: the script ends with `→ offline fallback: scripts/stage-data.sh`. That copies the committed copies from `staged_data/` into `data/` — same files, same counts, no network:

🐳 Container shell
```bash
scripts/stage-data.sh
```
✅ Eight lines, one per file, with the same counts.

Why it is fast: Overture publishes every theme as Parquet files on a public S3 bucket, one row per feature with a `bbox` column ([docs.overturemaps.org/getting-data](https://docs.overturemaps.org/getting-data/)). DuckDB reads those files in place and skips every row group outside the box, so a county-sized extract takes **seconds**, not a planet download. For one theme, this is what [`scripts/fetch-overture.sh`](scripts/fetch-overture.sh) runs (with the box from `versions.env`):

```sql
INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;
SET s3_region = 'us-west-2'; SET geometry_always_xy = true;
COPY (
  SELECT id, class, subclass, names.primary AS name, routes[1].ref AS route_ref, geometry
  FROM read_parquet('s3://overturemaps-us-west-2/release/2026-09-23.1/theme=transportation/type=segment/*')
  WHERE subtype = 'road'
    AND bbox.xmin > -121.40 AND bbox.xmax < -120.52 AND bbox.ymin > 38.72 AND bbox.ymax < 39.20
) TO 'data/overture/roads.geojson' (FORMAT GDAL, DRIVER 'GeoJSON');
```
Nested Overture columns (`names.primary`, `routes[1].ref`, `taxonomy.primary`) are flattened on the way out, and list-typed columns are left behind — the GeoJSON writer cannot store them. `scripts/fetch-overture.sh roads` fetches just one theme.

Measured on a laptop (≈ 100 Mbit/s); the time is mostly spent reading Parquet metadata on S3, so it barely grows with the box:

| Theme | Placer box (0.42 sq. degrees, ≈ 45 × 33 miles) | 4 × 4 mile box (Bellevue, WA) |
|---|---|---|
| roads | 36,294 features · 17 MB · **5 s** | 2,499 · 1 MB · 4 s |
| water | 1,920 · 1.8 MB · 2 s | 138 · 88 KB · 1 s |
| towns | 121 · 26 KB · < 1 s | 4 · 4 KB · < 1 s |
| land cover | 2,564 · 4.2 MB · 3 s | 21 · 20 KB · 2 s |
| buildings | 12,606 (Auburn box) · 5.2 MB · 5 s | 14,541 (whole box) · 7 MB · 7 s |
| places | 27,096 · 9.2 MB · 9 s | 10,856 · 3.9 MB · 2 s |
| **all six** | **24 s** | **16–20 s** |

Alternative: Overture's own CLI does the same without SQL — `uvx overturemaps download --bbox=-121.40,38.72,-120.52,39.20 -f geojson --type=segment -o roads.geojson` (one call per type, same bucket).

**Hazard** comes from CAL FIRE's ArcGIS feature services ([`scripts/fetch-hazard.sh`](scripts/fetch-hazard.sh) pages through them with `f=geojson`, so the server reprojects from California State Plane feet to lon/lat for us). **Shelters** are hand-checked from county releases: only Sierra College is `verified` (it was the Mosquito Fire shelter in 2022); everything else is `candidate`.

**After Fetch, [`data/`](data/) holds** plain **GeoJSON**, one file per theme, clipped to the study box (a committed copy lives in `staged_data/` for offline use). These are the files we explore in this phase and turn into map artifacts in Phase 2:

| File | What | From | Features |
|---|---|---|---|
| `data/overture/roads.geojson` | drivable roads, with `class` (motorway … residential), `name`, `route_ref` | Overture `transportation/segment` | 36,294 |
| `data/overture/water.geojson` | lakes, reservoirs, rivers (polygons) | Overture `base/water` | 1,920 |
| `data/overture/towns.geojson` | city / town / village / hamlet points with `population` → map labels | Overture `divisions/division` | 121 |
| `data/overture/land_cover.geojson` | forest, shrub, crop … polygons | Overture `base/land_cover` (ESA WorldCover) | 2,564 |
| `data/overture/buildings.geojson` | building footprints with `height` — Auburn only (3D layer) | Overture `buildings/building` | 12,606 |
| `data/overture/places.geojson` | points of interest with `category` and `confidence` — used to find shelter candidates | Overture `places/place` | 27,096 |
| `data/hazard/fhsz.geojson` · `fire_perimeters.geojson` | Fire Hazard Severity Zones (Moderate / High / Very High) · Mosquito 2022 and River 2021 | CAL FIRE | 355 · 2 |
| `data/shelters.geojson` | the hand-checked shelter list: `id, name, status, type, town, source` | by hand | 10 (1 verified) |

**DuckDB** is a SQL engine that reads those files in place — no database to set up. `duckdb -c "…"` runs one command and exits; `.read file.sql` runs every statement in that file, so each step below is one SQL file we can open and read, and **the expected output is written above every query**. Two spatial idioms appear everywhere: `LOAD spatial;` switches the geo extension on, and `ST_Read('file.geojson')` opens a GeoJSON file as a table (column `geom` is the shape).

**1a · Look around** — what is in the data before touching it · 🐳 Container shell
```bash
duckdb -c ".read 00-data/01-explore.sql"
```
Three plain `SELECT`s over `roads.geojson` and `places.geojson`: which columns the roads table has (`DESCRIBE`), how many roads there are per class (`GROUP BY`), and the 15 most common place categories.

✅ The roads by class add up to **36,294** — the number every later step must reproduce.

**1b · Which places could be shelters, and do they sit in a hazard zone?** · 🐳 Container shell
```bash
duckdb -c ".read 00-data/02-shelters.sql"
```
First filters Overture places by category and confidence (19 "community centers" — one is a car dealer: category data is a hint, not a fact), then opens the hand-checked `data/shelters.geojson` and intersects it with the CAL FIRE hazard polygons (`ST_Intersects` — a yes/no question about two shapes). The last table is the point of the exercise — three of the ten shelters are inside a *Very High* zone.

✅ We should see
```text
│ Colfax High School            │ candidate │ school           │ Very High        │
│ Georgetown School             │ candidate │ school           │ Very High        │
│ Sierra Vista Community Center │ candidate │ community_center │ Very High        │
```

**1c · Export** — write a GeoJSON file with SQL · 🐳 Container shell
```bash
duckdb -c ".read 00-data/03-export.sql"
```
`COPY (query) TO 'file.geojson' (FORMAT GDAL, DRIVER 'GeoJSON')` — this is how `scripts/fetch-overture.sh` wrote every file in `data/overture/`. Here the query is the "shelter-ish" filter from 1b, reshaped into the columns of `shelters.geojson` with `status = 'candidate'`. Phase 4 runs this same file for our own community and we keep the real ones.

✅ `out/shelter-candidates.geojson` exists (the checkpoint counts it).

**Checkpoint** · 🐳 Container shell
```bash
duckdb -c "LOAD spatial; SELECT type, count(*) FROM ST_Read('out/shelter-candidates.geojson') GROUP BY type ORDER BY 2 DESC"
```
✅ 95 candidates: 39 schools, 19 community centers, 18 colleges, 8 town halls, 7 fairgrounds, 4 `stadium_arena`. Nothing later depends on this file — anyone behind can move on. Fetch's files are different: 1a, 1b and Phase 2 read them, so whoever is behind on Fetch runs `scripts/stage-data.sh` and moves on.

<details><summary><b>▸ Optional · tour every Overture theme</b> (which theme each file came from, one breakdown per file)</summary>

🐳 Container shell
```bash
duckdb -c ".read 00-data/04-overture-themes.sql"
```
Eight queries with their expected output in the file: an inventory of the six files; the box they cover; numbered routes by length (I-80 143.7 km, CA-49, CA-193 …); the place-confidence ladder; water and land-cover classes by area; the biggest towns by population (Roseville 107,158); building heights. More SQL to try: [`00-data/exercises.md`](00-data/exercises.md) (**A** primary-and-up roads · **B** nearest shelter to Foresthill as the crow flies — remember it for Phase 3 · **C** re-export for the Colfax box).

✅ Each query's output matches the comment above it in the file.

</details>

---

## Phase 2 — Map artifacts · the three files the app needs

The application in Phase 3 reads exactly three things, and this phase makes each one:

| | Artifact | Made by | From |
|---|---|---|---|
| **2a** | **Tiles** — `out/evac.pmtiles`, one file with 8 vector layers | Planetiler | the GeoJSON in `data/` |
| **2b** | **Routing graph** — `data/osrm/study-area.osrm.*`, what the `osrm` container serves | OSRM | an OpenStreetMap extract (`.osm.pbf`) |
| **2c** | **Reach bands (isochrones)** — `data/coverage/coverage_bands.geojson`, 10 / 20 / 30-minute drive-time rings per shelter | `scripts/make-coverage.py` | the routing graph + the shelters |

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef tool fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26

  GJ[/"data/**/*.geojson"/]:::file
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

### 2a · Tiles

🐳 Container shell · about 4 s
```bash
01-tiles/build.sh
pmtiles show out/evac.pmtiles
curl -sSI -H "Range: bytes=0-15" "$WEB_URL/out/evac.pmtiles" | head -1
```
✅ `min zoom 4` · `max zoom 14` · `1607` tiles, then `HTTP/1.1 206 Partial Content`. Layer names: add `--metadata`, or read row 0 of the map page in Phase 3.

❌ Anything other than `206` → the wrong web server (**If something is red**, first row).

`build.sh` runs one Java command: Planetiler reads the eight GeoJSON files through the schema [`01-tiles/evac.yml`](01-tiles/evac.yml) — which layer each file becomes, from which zoom each class appears (motorways from 6, residential streets from 10, buildings from 13), which attributes survive into the tiles — and writes **one** archive. PMTiles is a single file the browser reads in pieces with HTTP Range requests; that is what the `206` check is for. Change a number in `evac.yml`, rebuild in 4 s, click **Reload** on row 0 of the map (Phase 3).

### 2b · Routing graph

OSRM needs its own graph, pre-computed once from an OpenStreetMap extract — Overture's roads are for drawing, OSM's `.osm.pbf` carries the turn restrictions and speed limits a router needs.

<details><summary><b>▸ Optional · Build the routing graph ourselves, from an OpenStreetMap snapshot</b> (Geofabrik → osmium → OSRM; this is what Phase 4 does for our own box)</summary>

Routing does not use the Overture roads: OSRM reads OpenStreetMap's own `.osm.pbf` format, with turn restrictions and speed limits.

1. **Get a snapshot.** [Geofabrik](https://download.geofabrik.de) publishes one `.osm.pbf` per continent / country / state / sub-region, refreshed daily. Pick the smallest region that contains the box (Northern California: `norcal-latest.osm.pbf`, ≈ 1 GB; a small US state 100–400 MB) and put its URL in `OSM_EXTRACT_URL` in `versions.env`. Similar sites: [BBBike extracts](https://extract.bbbike.org) (draw any box), [Protomaps](https://protomaps.com/downloads) (smaller areas).
2. **Cut the box out of it** — `osmium extract` keeps every way that touches the box complete (`-s smart`):
   🐳 Container shell
   ```bash
   scripts/fetch-osm.sh
   ```
   ✅ Downloads `OSM_EXTRACT_URL` once into `data/osm/`, then writes `data/osm/study-area.osm.pbf` (17 MB for the Placer box).
3. **Build the graph** — three OSRM commands in the pinned OSRM container: `osrm-extract` reads the roads with the car profile (speeds per road class), `osrm-partition` and `osrm-customize` precompute the shortcuts that make `/table` and `/route` answer in milliseconds. **Laptop terminal** (option B) or the Codespaces terminal — the script runs Docker, so it only prints what it would do inside `docker compose exec`:

   💻 Laptop terminal (option B) · the Codespaces terminal (option A)
   ```bash
   scripts/build-osrm.sh data/osm/colfax.osm.pbf out/osrm
   scripts/build-osrm.sh
   docker compose restart osrm
   ```
   ✅ First a tiny clip (about 1 min → `out/osrm/colfax.osrm.*`, just to watch it happen), then the study area (15 s → `data/osrm/study-area.osrm.*`, 99 MB), then OSRM restarts on the new graph. Codespaces without Compose: `docker restart $(docker ps -qf name=osrm)`.
   The container then serves it: `osrm-routed --algorithm mld /data/study-area.osrm` (see `docker-compose.yml`).

</details>

**The routing graph is staged in `data/osrm/study-area.osrm.*`** (26 files, 99 MB, from the data bundle) and the `osrm` container is already serving it — this is the second artifact, used by 2c and by the routing in Phase 3.

**Verify the graph answers** — two HTTP calls; the whole routing API is URLs like these · 🐳 Container shell
```bash
curl "$OSRM_URL/nearest/v1/driving/-121.08,38.90"
curl "$OSRM_URL/route/v1/driving/-120.8182,39.0199;-121.0709,38.8952?overview=false"
```
✅ First `{"code":"Ok", …}` (the road point nearest to Auburn), then `"duration": ≈ 2150` (seconds, ≈ 36 min) and `"distance": ≈ 31800` (m) — Foresthill → Placer High School.

### 2c · Reach bands (isochrones)

Drive time from every road-bearing H3 cell (res 8, 3,341 cells) to all 10 shelters in a handful of OSRM `/table` calls, dissolved into non-overlapping 0–10 / 10–20 / 20–30-minute rings per shelter · 🐳 Container shell
```bash
scripts/make-coverage.py
```
✅ About 2 s; writes `data/coverage/coverage_hex.geojson` + `coverage_bands.geojson`. Run it as written (uv shebang); it talks to `$OSRM_URL` (`--osrm <url>` to point it elsewhere). It first checks that the graph OSRM serves covers the box, and names any OSRM error (`NoSegment`, `InvalidQuery`) instead of a bare `HTTP Error 400`.
"Isochrone" just means "same-time line". OSRM has no isochrone call, so the script asks for many point-to-shelter times and draws the rings itself with DuckDB spatial.

More to try: [`01-tiles/exercises.md`](01-tiles/exercises.md) (**A** layers and zooms · **B–C** change `evac.yml` and compare sizes · **D** hazard classes · **E** OSM input size · **F** which shelter reaches the most ground).

---

## Phase 3 — Application · the map, three views, nearest shelter by road

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef step fill:#FFFFFF,stroke:#8A939B,color:#161D26
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26
  classDef out  fill:#FEE3D8,stroke:#FF6101,color:#161D26

  PM[/"out/evac.pmtiles<br/>coverage_bands.geojson"/]:::file
  S["3a · Fire evac map<br/>Edit → Add rows 0–4"]:::step
  V["3b · Shelter reach<br/>Edit → Add the rings"]:::step
  R["3c · Routing<br/>Edit → Add → click · drag · I-80"]:::step
  D(["3d · demo/<br/>the finished app"]):::out
  PM --> S --> V --> R --> D
```

🌐 Browser · open <http://localhost:8080/02-web/> (Codespaces: Ports → 8080 → globe → add `/02-web/`).

✅ The map is blank. Click **Edit** (top-left): a panel lists the data files, one row each. Every row has a text box **prefilled with the workshop file** (a path from the repo root) and an **Add** button; clicking **Add** puts that file into the map. **Nothing is typed or edited in this phase** — leave the boxes as they are, every step below is one click. (The boxes exist for Phase 4: type another path or a URL to plug in another file.) What is added stays until the page is refreshed.

### 3a · Style — stay on **Fire evac map**, click **Edit**, then **Add** on each row, top to bottom

**0 · Tiles → Add.** The row turns green and lists what is in the file (1607 tiles · zoom 4–14 · 8 layers: buildings, fire_perimeters, hazard, land_cover, roads, shelters, towns, water), a **dashed box** shows the area the tiles cover, and rows 1–4 unlock. Nothing else is drawn yet — the tiles are data; rows 1–4 are the drawing instructions. (A note "Using the prebuilt tiles" means `out/evac.pmtiles` from 2a was not found — fine, carry on.)

<img src="docs/img/p3-step0-tiles.jpg" width="80%" alt="Edit panel after Add on row 0: green tick with 1607 tiles and 8 layer names, dashed box around the study area, rows 1–4 now clickable"/>

**1 · Roads → Add.** Grey road network.

<img src="docs/img/p3-step1-roads.jpg" width="80%" alt="Grey roads over a blank background"/>

**2 · Hazard zones, water, land cover, shelters, town labels → Add.** The map now matches the legend: Moderate / High / Very High fill, blue water, green land cover, 10 shelter circles (filled = verified), town names.

<img src="docs/img/p3-step2-hazard.jpg" width="80%" alt="Hazard classes, water, land cover, shelter circles and town labels"/>

**3 · Past fire perimeters → Add.** Thin dashed outlines of the Mosquito 2022 and River 2021 fires (north-east, around Foresthill and Colfax).

<img src="docs/img/p3-step3-perimeters.jpg" width="80%" alt="Dashed fire perimeters added"/>

**4 · 3D buildings → Add**, then zoom in over Auburn (past zoom 13) and right-drag to tilt.

<img src="docs/img/p3-step4-buildings.jpg" width="80%" alt="3D buildings over Auburn, tilted view"/>

Each row is a plain JSON file of MapLibre layers in [`02-web/steps/`](02-web/steps/). Want to change a colour or a width? Open that row's file, edit, click the row's **Reload**. Lost? [`02-web/solution.html`](02-web/solution.html) is the page with everything added.

### 3b · Shelter reach — click **Shelter reach** (top-left), then **Edit**

**Reach rings → Add.** Hexagon bands around every shelter: green ≤ 10 min · blue ≤ 20 · light red ≤ 30 min drive (Phase 2c output). Click a shelter to see only its rings; click the map to see all again. (Rows 0, 1 and 2 are already green after 3a; if not, Add them first. Row 2 is relabelled here — "Water, shelters, town labels" — because hazard and land cover stay hidden in this view.)

<img src="docs/img/p3-reach-rings.jpg" width="80%" alt="Shelter reach view with 10/20/30-minute drive-time bands"/>

**Base map** (the third button) needs nothing added: a standard street map under the shelters, internet required. It is the [Esri World Street Map](https://www.arcgis.com/home/item.html?id=3b93337983e9436f8db950e38a8629af) raster service (no API key, worldwide, attribution required) rather than `tile.openstreetmap.org` on purpose — the OSM tile servers' [usage policy](https://operations.osmfoundation.org/policies/tiles/) throttles bulk requests from a single address, and a workshop room behind one NAT address is exactly that. Any `{z}/{x}/{y}` raster service works here; it is one `tiles` URL in the style. The three views are strictly one at a time — switching only flips layer visibility; nothing is drawn on top of something else.

More to try: [`02-web/exercises.md`](02-web/exercises.md) (**A** recolour streets · **B** verified shelter only · **C** Very High hazard only · **D** why some shelters have fewer rings) — on a copy in `out/`, loaded through the row 4 box.

### 3c · Routing — in **Fire evac map** or **Shelter reach**, **Edit** → **Routing → Add**

**Routing → Add.** A pin drops on Foresthill and a pink line is drawn to the nearest shelter **by road**: Placer High School, ~36 min, 31.8 km. Nothing to write.

<img src="docs/img/p3-routing.jpg" width="80%" alt="Pin on Foresthill, pink route to Placer High School, popup 36 min"/>

**Drag the pin**, then tick **I-80 closed** (top-right). The route recomputes without the motorway. From Gold Run: Sierra Vista CC 13 min → **21 min**.

<img src="docs/img/p3-routing-i80.jpg" width="80%" alt="I-80 closed ticked: pin at Gold Run, detour route to Sierra Vista Community Center, 21 min"/>

Nearest on the map ≠ nearest by road: from Foresthill, Georgetown School is 12.4 km away but 59.7 min; Placer High is 35.8 min. Under the hood it is two calls to OSRM — `/table` (seconds from the pin to every shelter, pick the smallest) and `/route` (the line); I-80 closed adds `&exclude=motorway` to both. Once loaded, routing works in every view.

> A real closure is not a URL parameter. This is the calculation, not detection; shelter status, traffic, smoke and capacity are not in the data.

<details><summary><b>▸ Optional · Write the routing ourselves</b> — the same module in three steps, instead of clicking Add</summary>

The Routing row loads [`03-routing/route.js`](03-routing/route.js). To build it by hand, open `02-web/index.html`, find the three commented `import('../03-routing/…')` lines at the end, and work through them (each module exports `start(map, maplibregl)`):

**Step 1 · Hello route** · ✏️ edit the file `02-web/index.html` — uncomment `import('../03-routing/steps/step1-route.js')`, reload → a pink line Foresthill → Placer High School; console: `Route: 35.8 min, 31.8 km`. No line? Console (F12): a red `/osrm 404` means the :8080 server is not Caddy.

**Step 2 · Nearest shelter by road** · ✏️ edit the files `02-web/index.html` and `03-routing/steps/step2-scaffold.js` — switch the import to `steps/step2-scaffold.js`; in it, fill the block `WE WRITE THESE 6 LINES`:
1. `/table` with `sources=0&annotations=duration,distance` (pin first, then the 10 shelters)
2. `secs = durations[0]` without its first entry (pin → pin)
3. `best = argmin(secs)`
4. `/route` to the best shelter, `overview=full&geometries=geojson`
5. `setRoute(route.geometry)`
6. `showPopup(…, "Name · ~N min drive (free-flow, no traffic) · K km")`

Expected (start = Foresthill): **Placer High School · ~36 min · 31.8 km**. Drag the pin anywhere in the box: the route recomputes. Stuck? point the import at `steps/step3-solution.js` (same code as `route.js`).

**Step 3 · "I-80 is closed"** — add `&exclude=motorway` to both URLs (the finished version is the checkbox top-right). From **Dutch Flat (-120.838, 39.198)** to Sierra Vista Community Center: 17.9 min → **31.3 min**, via Dutch Flat Rd / Magra Rd / Rollins Lake Rd.

The three OSRM calls (HTTP API v1, profile `driving`):

| Call | Answers |
|---|---|
| `GET $OSRM_URL/nearest/v1/driving/{lon},{lat}` | which road point is closest to the pin |
| `GET $OSRM_URL/table/v1/driving/{pin};{s1};…;{s10}?sources=0&annotations=duration,distance` | `durations[0][i]` seconds and `distances[0][i]` metres, pin → each shelter |
| `GET $OSRM_URL/route/v1/driving/{pin};{winner}?overview=full&geometries=geojson[&exclude=motorway]` | `routes[0].geometry`, `.duration` (s), `.distance` (m) |

Stretch: [`03-routing/exercises.md`](03-routing/exercises.md) — 400 grid points → one `/table` POST → colour the map by drive time ([`03-routing/grid.sql`](03-routing/grid.sql)).

</details>

### 3d · The finished app — [`demo/`](demo/)

The same three views + the router with a side panel (view switch, legend, I-80 toggle, result). Static files only — MapLibre, PMTiles and GeoJSON; the only server is OSRM. 🌐 Browser · <http://localhost:8080/demo/> · URL state: `?lng=&lat=&closed=1&view=reach&shelter=placer-high`. On the public Pages site it falls back to `router.project-osrm.org` (no `exclude=motorway` there).

<img src="docs/img/demo-app.jpg" width="80%" alt="demo app: Fire evac map view with a pin and the route to the nearest shelter"/>

---

## Phase 4 — Adapt · a community of our choice

Everything above was driven by **one box** — the four `BBOX_*` lines in [`versions.env`](versions.env). Phase 4 is the same steps with a different box. Network needed; the OpenStreetMap region download is the big one.

> **Phase 4 overwrites the Placer files** — `versions.env`, what the scripts generate in `data/`, `out/evac.pmtiles`, and two page files in step 8. No git needed: keep a copy, start clean, rebuild.
>
> 🐳 Container shell
> ```bash
> cp -R data data.placer
> rm -f data/overture/*.geojson data/hazard/*.geojson data/coverage/*.geojson data/shelters.geojson out/evac.pmtiles
> ```
> ✅ `data.placer/` keeps Placer (≈ 170 MB, mostly the routing graph) — undo later with `rm -rf data && mv data.placer data`. The second line starts clean; steps 2–7 regenerate every one of these files.
>
> Every block below is labelled: most run in the 🐳 container shell, step 5 has one 💻 laptop-terminal block.

```mermaid
flowchart LR
  classDef file fill:#E6F0FF,stroke:#0678FF,color:#161D26
  classDef tool fill:#161D26,stroke:#161D26,color:#FFFFFF
  classDef step fill:#FFFFFF,stroke:#8A939B,color:#161D26
  classDef chk  fill:#E6F5EA,stroke:#2E8B57,color:#161D26

  VE[/"1 · versions.env<br/>BBOX_W/S/E/N · OSM_EXTRACT_URL"/]:::file
  OV["2 · fetch-overture.sh<br/>six themes → GeoJSON"]:::tool
  HZ["3 · fetch-hazard.sh<br/>(or --none)"]:::tool
  SH["4 · shelters<br/>03-export.sql → pick-shelters.sh → data/shelters.geojson"]:::step
  RG["5 · fetch-osm.sh → build-osrm.sh<br/>routing graph"]:::tool
  TL["6 · build.sh → tiles<br/>7 · make-coverage.py → reach bands"]:::tool
  AP(["8 · the same pages<br/>Edit → Add · demo"]):::chk
  VE --> OV --> HZ --> SH --> RG --> TL --> AP
```

**1 · The box.** Draw it on [bboxfinder.com](http://bboxfinder.com) (bottom-left shows W,S,E,N), keep it under ~0.5 square degrees, and edit `versions.env`:

✏️ edit the file `versions.env` (not a terminal paste)
```ini
BBOX_W=-122.244    # west   (longitude, negative in the Americas)
BBOX_S=47.581      # south
BBOX_E=-122.159    # east
BBOX_N=47.639      # north
BUILDINGS_W=-122.244   # the box for 3D buildings — for a town-sized box, the same four numbers again
BUILDINGS_S=47.581
BUILDINGS_E=-122.159
BUILDINGS_N=47.639
OSM_EXTRACT_URL=https://download.geofabrik.de/north-america/us/washington-latest.osm.pbf   # the Geofabrik region that contains the box
```
✅ `versions.env` holds the new box and region.

**2 · Overture themes for the box** — the same script as Phase 1 · Fetch, for our own box (20–40 s — buildings take longest, 20,000 of them ≈ 17 s; the table in Phase 1 has the per-theme times). A theme with nothing in the box (land cover in a city centre) is written as an *empty layer* — one feature, no geometry — so the tile build still runs; the map simply has no such layer.

🐳 Container shell
```bash
scripts/fetch-overture.sh
duckdb -c ".read 00-data/01-explore.sql"
```
✅ Six files in `data/overture/` (`roads`, `water`, `towns`, `land_cover`, `buildings`, `places`), then the same three queries over the new roads and places.

**3 · Hazard** — the same script as Phase 1 · Fetch, for our own box. In California, CAL FIRE's zones and perimeters for the box (`FIRE_PERIMETERS_WHERE` in `versions.env` picks the fires, e.g. `YEAR_ >= 2015`). Anywhere else there is no CAL FIRE: write two empty layers so the pipeline runs, and swap in local polygons later (below).

🐳 Container shell · California
```bash
scripts/fetch-hazard.sh
```
🐳 Container shell · anywhere else
```bash
scripts/fetch-hazard.sh --none
```
✅ `data/hazard/fhsz.geojson` + `fire_perimeters.geojson` exist (with `--none`: no features).
A city box can come back in a second with one zone and no perimeters — that is the real answer, not a failure (downtown Los Angeles: 1 FHSZ polygon, 0 fires since 2015).

**4 · Shelters.** Run the Phase 1c export for the box, open the result, keep the places that really are shelters, and save them as `data/shelters.geojson` — same columns (`id, name, status, type, town, source`), short unique `id`s, `status = candidate` until a county source confirms one.

🐳 Container shell
```bash
duckdb -c ".read 00-data/03-export.sql"
duckdb -csv -c "LOAD spatial; SELECT id, name, type, town FROM ST_Read('out/shelter-candidates.geojson') ORDER BY type, name" > out/shelter-candidates.csv
cat out/shelter-candidates.csv
```
✅ The candidates printed, one per line as `id,name,type,town` (schools, community centers, colleges, town halls, fairgrounds, arenas) — `id` is the name as a slug (`Placer High School` → `placer-high-school`). Note the ids to keep.

🐳 Container shell · ✏️ edit first: the ids
```bash
scripts/pick-shelters.sh colfax-high-school placer-high-school
```
✅ `data/shelters.geojson` holds the kept places, all `status = candidate`; the ids are the first column of the list above. Nothing matched? The high schools in the box stand in (any K-12 school if there is none); `--auto` asks for that outright.

**5 · Routing graph** — the OpenStreetMap snapshot, clipped, then the three OSRM commands (details: Phase 2b ▸ Optional):

🐳 Container shell
```bash
scripts/fetch-osm.sh
```
✅ Downloads `OSM_EXTRACT_URL` once (a Geofabrik state or sub-region: 100 MB – 1 GB; socal 641 MB ≈ 1 min) and clips it → `data/osm/study-area.osm.pbf`.

💻 Laptop terminal (option B) · the Codespaces terminal (option A)
```bash
scripts/build-osrm.sh
docker compose restart osrm
```
✅ `data/osrm/study-area.osrm.*` rebuilt and OSRM restarted. Codespaces without Compose: `docker restart $(docker ps -qf name=osrm)`.

❌ Typed in the container shell, `build-osrm.sh` only prints what it would do and exits 0 — the old graph stays.

🐳 Container shell · ✏️ edit first: `<lon>,<lat>` (a point inside the box)
```bash
curl "$OSRM_URL/nearest/v1/driving/<lon>,<lat>"
```
✅ `{"code":"Ok","waypoints":[{"distance":<a few metres> …`
`"code":"Ok"` alone proves nothing — OSRM snaps to the nearest road it has, even 900 km away. Look at `distance`: a few metres means the new graph is serving; thousands of metres means the old graph is still loaded (restart again). The region file stays in `data/osm/` for the next clip; delete it when done (`rm data/osm/<region>-latest.osm.pbf`).

**6 · Tiles** and **7 · Reach bands** — exactly Phase 2a and 2c:

🐳 Container shell
```bash
01-tiles/build.sh
scripts/make-coverage.py
```
✅ `out/evac.pmtiles` (`pmtiles show out/evac.pmtiles` shows the NEW bounds and 5–8 layers; an empty layer is left out) and `data/coverage/*.geojson`. `make-coverage.py` uses `$OSRM_URL` and stops with a clear line if OSRM still serves the old graph ("the nearest road to the box centre is 595 km away" → step 5 again).

**8 · The pages.**
- **`02-web/`**: refresh, **Edit → Add** the rows as in Phase 3 — they already point at the files just rebuilt, and the map fits itself to the new tiles. For routing, edit the two marked lines at the top of [`03-routing/route.js`](03-routing/route.js) (`STUDY_BBOX`, `START` — the pin must drop inside the box), then **Routing → Add**.
- **`demo/`**: `cp out/evac.pmtiles data/prebuilt/evac.pmtiles`, then edit the three marked lines at the top of [`demo/app.js`](demo/app.js) (`BBOX`, `CENTER`, `ZOOM`). Without a hazard layer the Fire evac view shows roads, water, land cover and towns; the other two views are unchanged.
- **Words that still say Placer** (cosmetic, optional): the two page titles, the **I-80 closed** label (it sends `exclude=motorway`, so it closes every freeway in the new box — rename it, keep it), the perimeter names in the `demo/index.html` legend, and `schema_description` in [`01-tiles/evac.yml`](01-tiles/evac.yml) (what `pmtiles show` prints). `grep -n -E 'Placer|I-80|Auburn|Foresthill' 02-web/index.html demo/index.html demo/app.js 03-routing/route.js 01-tiles/evac.yml` lists every line.

**9 · Check and publish.** `sha256sum data/overture/*.geojson data/hazard/*.geojson data/shelters.geojson > my-checksums.sha256` records what was built; `out/evac.pmtiles` + `data/coverage/` + `data/shelters.geojson` + `02-web/` + `demo/` on any static host that answers Range requests is a published map. Keep the attribution line and the disclaimer.

<details><summary><b>▸ Worked example · Bellevue, WA — a 4 × 4 mile box</b></summary>

Box `-122.244, 47.581, -122.159, 47.639` (downtown Bellevue, the I-405 / I-90 interchange, Lake Washington on the west edge), `OSM_EXTRACT_URL = …/us/washington-latest.osm.pbf`, `scripts/fetch-hazard.sh --none` (no CAL FIRE outside California).

| Step | Result |
|---|---|
| 2 `fetch-overture.sh` | 16–20 s · roads 2,499 · water 138 · towns 4 · land cover 21 · buildings 14,541 · places 10,856 |
| 4 `03-export.sql` | 12 candidates: 4 schools, 3 community centers, 3 town halls, 2 for-profit colleges (Bellevue College itself sits just outside the box). Drop the colleges and "service center" rows → 5–8 shelters, all `candidate` |
| 5 `fetch-osm.sh` → `build-osrm.sh` | Washington extract ≈ 365 MB (once); clip ≈ 9 s, graph ≈ 2 s |
| 6 `build.sh` | 47 tiles · `pmtiles show` → bounds -122.244 … 47.639 · **6 layers** — hazard and fire_perimeters are empty, so Planetiler leaves them out; the map page says "6 layers" and rows 2–3 simply draw nothing |
| 7 `make-coverage.py` | a few dozen H3 cells; bands mostly ≤ 10 min — it is a small box |
| 8 | `route.js`: `STUDY_BBOX = [-122.244, 47.581, -122.159, 47.639]`, `START = [-122.2015, 47.6101]` · `demo/app.js`: `BBOX` same, `CENTER = [-122.20, 47.61]`, `ZOOM = 13` |

</details>

<details><summary><b>▸ Worked example · Downtown Los Angeles — a 4 × 4 mile city box</b></summary>

Box `-118.29, 34.02, -118.22, 34.07` (City Hall and the 110 / 101 / 10 freeway interchanges), `OSM_EXTRACT_URL = …/us/california/socal-latest.osm.pbf`, `FIRE_PERIMETERS_WHERE="YEAR_ >= 2015"`. Run from the pulled images (Phase 0 option B), start to finish, by someone who had only this page.

| Step | Result |
|---|---|
| 2 `fetch-overture.sh` | 33 s · roads 3,870 · water 147 · towns 1 · **land cover 0** (written as an empty layer) · buildings 20,933 · places 38,394 |
| 3 `fetch-hazard.sh` | 1 s · 1 FHSZ polygon · 0 perimeters since 2015 — a city centre |
| 4 `03-export.sql` | 175 candidates: 88 colleges, 44 schools, 20 community centers, 14 arenas, 8 town halls, 1 fairground. Most "colleges" are departments and academies; keep ~8 — City Hall, the schools and community centers well inside the box |
| 5 `fetch-osm.sh` → `build-osrm.sh` | SoCal extract 641 MB in ≈ 50 s (once); clip 12 s → 4 MB; graph 3 s, 17 MB · `/nearest` at City Hall → `distance` 19.5 m |
| 6 `build.sh` | 25 tiles · zoom 4–14 · 955 kB · **6 layers** (buildings, hazard, roads, shelters, towns, water) |
| 7 `make-coverage.py` | 45 H3 cells in 7 bands; a shelter on the box edge got 0 cells |
| 8 | `route.js`: `STUDY_BBOX = [-118.29, 34.02, -118.22, 34.07]`, `START = [-118.249, 34.045]` · `demo/app.js`: `BBOX` same, `CENTER = [-118.255, 34.045]`, `ZOOM = 13` · a click near City Hall → "Los Angeles City Hall · ~3 min drive · 2 km" |

</details>

<details><summary><b>▸ Swap the hazard</b> — flood zones, live fire feeds, a county's own polygons</summary>

The hazard layer is one polygon file with a class column (`FHSZ_Description` = Moderate / High / Very High). Replace the file, keep the SQL and the style — or rename the class in `02-web/steps/step2-hazard-water.json` and `demo/style.json` (`match` on `FHSZ_Description`).

| Hazard | Source | How |
|---|---|---|
| **Flood** — FEMA National Flood Hazard Layer (public domain) | `https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer` (flood-hazard-zones layer) | same pattern as `scripts/fetch_arcgis.py`: `…/query?where=1=1&geometry=W,S,E,N&geometryType=esriGeometryEnvelope&inSR=4326&outFields=*&f=geojson`; style by the flood-zone field (`A` / `AE` are the mapped high-risk zones). Untested in the workshop build |
| **Wildfire, live** — CAL FIRE active incidents | `https://incidents.fire.ca.gov/umbraco/Api/IncidentApi/GeoJsonList` (undocumented, no SLA) | points with `Name`, `AcresBurned`, `PercentContained`, `IsActive` |
| **Evacuation zones, live** — Cal OES | `https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services/CA_EVACUATIONS_CalOESHosted_view/FeatureServer/0` | only publishes zones with an active order / warning; empty most days |
| **Wildfire, static** — CAL FIRE FHSZ (what we use) | `CALFIRE_FHSZ_URL` in `versions.env` | `scripts/fetch-hazard.sh` |

> ⚠️ **Going live raises the stakes on every caveat in the disclaimer.** A static hazard layer that is out of date is embarrassing; a live perimeter that is out of date, or a "safe" route through a road nobody has mapped as closed, can hurt someone. Before wiring a live feed into anything people will use: show the feed's own timestamp on the map, say what the data does *not* contain (shelter status, closures, capacity; drive time ≠ evacuation time), and send people to the official sources.

</details>

<details><summary><b>▸ Change the look</b> — road and building colours</summary>

Every colour on the map is one line in a MapLibre layer; the layers live in `02-web/steps/step4-final.json` (what row 4 loads), `02-web/solution.html` and `demo/style.json`. Work on a copy so the workshop files stay untouched:

🐳 Container shell
```bash
cp 02-web/steps/step4-final.json out/my-style.json
```
Open `out/my-style.json` (the repo folder is the same on the laptop) and change the colours:

| Layer `id` | Property | Now | Try |
|---|---|---|---|
| `roads-minor` — local streets | `"line-color"` | `"#aaaaaa"` | `"#8d6e63"` (brown) |
| `roads-major` — motorway/trunk, then primary/secondary | `"line-color"`: `["match", ["get","class"], [motorway…], "#555555", "#777777"]` | two greys | `"#c62828"`, `"#ef6c00"` (red freeways, orange highways) |
| `buildings` — 3D footprints from zoom 13 | `"fill-extrusion-color"` | `"#d9d9d9"` | `"#b0bec5"`, or by height: `["interpolate", ["linear"], ["get","height"], 0, "#eceff1", 30, "#546e7a"]` |

In the **Edit** panel type `out/my-style.json` into the row 4 box and click **Reload**. A layer with the same `id` replaces the one on the map; a JSON typo shows up as a notice naming the file (the browser's own JSON error — Chrome adds the line) and the map keeps the last good version. For the finished app, make the same edits in `demo/style.json` and refresh. Widths (`line-width`), opacity and the zoom at which a layer appears (`minzoom`) are edited the same way — [`02-web/exercises.md`](02-web/exercises.md) has more.

</details>

<details><summary><b>▸ Laptop → planet</b> — what changes at scale</summary>

| What we did on a laptop | What changes at scale |
|---|---|
| DuckDB reads Overture over S3 with bbox pushdown | Same query, bigger box. For a state or country, write one file per region and keep using the `bbox` columns, not `ST_Intersects`, to prune. |
| Planetiler `generate-custom` from GeoJSON, 4 s | Planetiler's built-in profiles read OSM PBF directly and build a planet on one large machine; `--bounds` limits it to a region. Output is the same PMTiles. |
| PMTiles on any static host (Range requests) | S3 + CloudFront / Cloudflare R2. No tile server. |
| OSRM MLD graph for 0.4 sq. degrees, 99 MB, 15 s | Large graphs need far more RAM and disk; use regional Geofabrik extracts, or Valhalla / GraphHopper / OpenRouteService when isochrones, traffic profiles or alternatives are needed built in. |
| `/table` 10 shelters × ~3,300 hexes | `--max-table-size` grows memory quadratically; batch the requests (as `scripts/make-coverage.py` does). |

</details>

---

## Stop everything

💻 Laptop terminal, in the clone folder
```bash
docker compose down
```
✅ The three containers are stopped and removed; images stay cached (`docker compose up -d` brings it back in seconds). To also delete the 3 GB of images: `docker compose down --rmi all`.

Option C: `Ctrl-C` in the `npx serve` terminal. Codespaces: <https://github.com/codespaces> → … → **Stop codespace** (it also stops itself after 30 idle minutes).

## If something is red

| Symptom | It means | Do |
|---|---|---|
| Blank map, row 0 red, or `curl … Range` answers `200` | the web server ignores Range requests | serve with Caddy (`docker compose up -d`) or `npx serve`, never `python -m http.server` |
| "Using the prebuilt tiles" on row 0 | `out/evac.pmtiles` not found | fine — or run 2a |
| Console: `/osrm 404` · "Routing needs OSRM" | the :8080 server is not Caddy, or no OSRM (option C) | use Caddy, or pair up |
| `osrm` container logs "waiting for data/osrm" | the graph is not there yet | `bash scripts/get-bundle.sh` (or Phase 4 step 5) |
| `check_setup.py`: OSRM / web server red on option C | expected without containers | continue; routing needs a neighbour |
| `java: command not found` · `Unsupported class file major version` | no Temurin 21 | option C install commands |
| `planetiler.jar` missing | not in git | `bash scripts/get-bundle.sh` or `curl -L -o 01-tiles/planetiler.jar https://github.com/onthegomap/planetiler/releases/download/v0.10.2/planetiler.jar` |
| `data/overture/roads.geojson missing` | Phase 1 · Fetch not run (or it failed) | `scripts/fetch-overture.sh && scripts/fetch-hazard.sh` · offline: `scripts/stage-data.sh` · after a Phase 4 box: `rm -rf data && mv data.placer data` |
| `zsh: unknown file attribute` · `zsh: command not found: #` | zsh read a `# note` as part of the command | `setopt interactivecomments`, then paste again |
| `unknown command: docker compose` · `unknown shorthand flag: 'd' in -d` | the `docker` CLI has no Compose plugin | Phase 0 B, ▸ No Docker Compose? |
| Points in the ocean off Africa | lon/lat swapped | the SQL files start with `SET geometry_always_xy = true;` — keep it |
| `.read` plus another statement in one `-c` does nothing | DuckDB dot-commands must be alone | one `.read` per run |
| Something else holds :8080 | an old server | `lsof -nP -iTCP:8080 -sTCP:LISTEN` (Windows: `netstat -ano \| findstr :8080`), then `kill <PID>` — or leave it and move: `WEB_PORT=8090 docker compose up -d`, then `localhost:8090` wherever this page says 8080 |
| `01-tiles/build.sh`: `WAR [<layer>:read] … Unexpected token type: START_OBJECT` · `Worker <layer>_read-1 died` · `NullPointerException` | that GeoJSON has zero features; Planetiler 0.10 cannot read an empty FeatureCollection (the warning names the token it *expected*) | `shelters`: the step-4 ids matched nothing — `scripts/pick-shelters.sh <ids from out/shelter-candidates.csv>` or `--auto` (`build.sh` itself substitutes the schools in the box, else a placeholder at the box's south-west corner). Other layers: `scripts/fetch-*.sh` write an *empty layer* (one feature, `"geometry": null`); for a file made another way, replace its contents with `{"type":"FeatureCollection","features":[{"type":"Feature","properties":{},"geometry":null}]}` |
| `make-coverage.py`: `HTTP Error 400` (older copy) · `OSRM … does not cover this box` · `OSRM InvalidQuery` | `NoSegment` / "595 km away": OSRM still serves the Placer graph · `InvalidQuery`: `data/shelters.geojson` has no features | Phase 4 step 5 on the **laptop** terminal (`scripts/build-osrm.sh`, `docker compose restart osrm`), check `curl "$OSRM_URL/nearest/…"` → `distance` of a few metres · step 4 again (`scripts/pick-shelters.sh`) |
| Two copies of the repo on one machine | Compose names the project after the folder | a second copy in a same-named folder, or one started with `-p <name>`, needs that same `-p <name>` on every `docker compose` command (`up`, `exec`, `restart`, `down`) |
| Codespace fails to create | the Docker helper feature | remove `docker-outside-of-docker` from `.devcontainer/devcontainer.json` and retry |

## Repository map

| Folder / file | What is in it | Phase |
|---|---|---|
| [`versions.env`](versions.env) | **the one config file**: the box, the OSM region, every tool and image pin | all |
| [`setup/`](setup/) | `check_setup.py` (green / red per tool, the tier, the next command) · `hello-geo.sql` (the checkpoint) · `exercises.md` | 0 |
| [`00-data/`](00-data/) | `01-explore.sql` · `02-shelters.sql` · `03-export.sql` · `04-overture-themes.sql` (optional tour) · `exercises.md` | 1 |
| [`01-tiles/`](01-tiles/) | `evac.yml` (the tile schema) · `build.sh` / `build.ps1` · `planetiler.jar` (from the bundle) · `exercises.md` (2a–2c) | 2a |
| [`scripts/`](scripts/) | `fetch-overture.sh` · `fetch-hazard.sh` (+ `fetch_arcgis.py`) · `stage-data.sh` (offline Fetch) · `pick-shelters.sh` + `shelters-fallback.sql` (Phase 4 step 4) · `fetch-osm.sh` · `build-osrm.sh` · `make-coverage.py` — the pipeline, one script per step · `get-bundle.sh` / `.ps1` · `lib.sh` · `check-versions.sh` (CI) · `make-bundle.sh`, `make-solution.py` (instructor) | 1 2 4 |
| [`02-web/`](02-web/) | `index.html` (the page) · `steps/*.json` (one file of MapLibre layers per Add row) · `solution.html` · `style.json` (the finished style, standalone) · `fonts/` (Noto Sans glyphs, offline labels) · `exercises.md` | 3a 3b |
| [`03-routing/`](03-routing/) | `route.js` (what the Routing row loads) · `steps/` (write it by hand) · `grid.sql`, `exercises.md` | 3c |
| [`demo/`](demo/) | the finished app: `index.html`, `app.js`, `style.json`, `dev-fixtures/` | 3d |
| [`data/`](data/) | `overture/`, `hazard/` (written by Phase 1 · Fetch, not in git) · `shelters.geojson` · `osm/`, `osrm/`, `prebuilt/evac.pmtiles` (from the bundle) · `coverage/` · [`LICENSE-data.md`](data/LICENSE-data.md) — licences **and provenance of every file** | all |
| [`staged_data/`](staged_data/) | committed copies of the Fetch output (`overture/`, `hazard/`) — the offline fallback, `scripts/stage-data.sh` | 1 |
| `out/` | what we build: `evac.pmtiles`, `shelter-candidates.geojson` | 1 2 |
| [`docker-compose.yml`](docker-compose.yml) · [`Caddyfile`](Caddyfile) · [`.devcontainer/`](.devcontainer/) | the three containers (tool shell, OSRM, Caddy) — options A and B share them | 0 |
| [`deck/`](deck/) | the slide deck shown in the room — `Routes-to-Safety-FOSS4G-NA-2026.pptx` and a PDF export | — |
| [`slides/`](slides/) · [`instructor/`](instructor/) | Marp source for the same talk · prep checklist (also: how to regenerate the data bundle and build the slides), wifi runbook | — |
| `docs/img/` | the screenshots on this page | — |

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
  **Data** keeps its source licences, listed with the provenance of every file in [`data/LICENSE-data.md`](data/LICENSE-data.md).
- Keep this line on every map: **© OpenStreetMap contributors · © Overture Maps Foundation · Fire Hazard Severity Zones: CAL FIRE FRAP (CC-BY) · Land cover: ESA WorldCover (CC-BY)**.

## Instructors

**Vishal Kumar** · **Shaishav Maisuria** — Amazon Maps. The workshop teaches only the public open stack.
