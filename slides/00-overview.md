---
marp: true
theme: rts
paginate: true
footer: Routes to Safety · FOSS4G NA 2026
size: 16:9
---

<!-- _class: door -->
<!-- _paginate: false -->

# Sit down. Start now.

## Start your Codespace (personal GitHub account) **or** run `docker compose pull`

**Codespaces users: sit next to a Docker user.**

<!-- Door slide, on screen before 09:00. Say (as people arrive): "Start your Codespace or `docker compose pull` as you sit down, during the title slide. Codespaces users, sit next to a Docker user." Staggers wifi load. -->

---
<!-- _class: lead -->
<!-- _paginate: false -->

# Routes to Safety

## An evacuation-services map from open geospatial data — datasets, tiles, routing, rendering

Vishal Kumar · Shaishav Maisuria
FOSS4G NA 2026 · Sacramento · Room Beavis

<div class="small">Slides, code and data: github.com/vishal4c/routes-to-safety-workshop &nbsp;·&nbsp; [QR placeholder: repo URL]</div>

<!-- S1. 1 min total for S1–S2. Say: "Good morning. In the next three hours we build an evacuation-services map for the Placer County I-80 corridor — and along the way get hands-on with open geospatial datasets, tile generation, a routing engine and a browser map renderer. If you haven't started your Codespace or docker compose pull, do it now while I talk." -->

---

# Who we are, and how to ask for help

- **Vishal Kumar** and **Shaishav Maisuria** — two instructors, both on the floor during the hands-on phases
- Sticky note on your laptop lid:
  - 🟩 **green** = I'm fine, keep going
  - 🟥 **red** = I'm stuck, come find me
- Red for more than 10 minutes → we switch you to another tier (next slide but two)
- Finish early? Help a neighbour, or try the next <span class="tier f">F</span>

<!-- S2. Say: "Two instructors. One of us talks, the other is already walking the room. Green sticky means you're fine, red means come and find me. If you're red for more than ten minutes we move you to a different way of running this — no shame, it's usually wifi or a corporate laptop." -->

---

# Agenda

| Time | What |
|---|---|
| 0:00 | Setup & welcome · the problem and the plan |
| 0:30 | **Extract** the data — DuckDB + Overture |
| 1:10 | Break (10 min) |
| 1:20 | **Build the basemap** — Planetiler, PMTiles, MapLibre |
| **2:05** | **Compute the routes — OSRM** |
| **2:37** | **Reproduce, adapt, scale** |
| 3:00 | Done |

<!-- S3. 1 min. Say: "Here's the whole morning. Two times to remember: at 2:05 you build live routing, and at 2:37 we adapt it to your own town. The break is at 1:10 and it's ten minutes." (Phase 3c is 2:05–2:37; Phase 4 is 2:37–3:00.) -->

---

# The pipeline in one picture

```text
Overture + OSM  ──►  DuckDB  ──►  GeoJSON  ──►  Planetiler  ──►  PMTiles  ──►  MapLibre
   (open data)     (spatial SQL)  (data/**.geojson) (your tiles)   (one file)    (the map)
                                                                                  │
                         OSRM graph ──►  /table  /route  /nearest  ───────────────┘
                                                              (routes + drive times)
```

- One study-area extract → **both** an evacuation-services map **and** live routes over it
- No database server, no tile server: files + a static web server (+ OSRM for routing)

<!-- S4. 1 min. Printed as a handout. Say: "This is the whole workshop in one picture. Data goes in on the left, a map and routes come out on the right. Every phase is one arrow on this slide. We'll fill in the pieces as we build them, and I'll show it again at the end." -->

---
<!-- _class: card -->

# 🧪 Three ways to run — and Phase 0

| Tier | For |
|---|---|
| **1 Codespaces** | no Docker · **personal GitHub account** · sit next to a Docker user |
| **2 Local Docker** | *recommended if you have Docker* — survives wifi loss |
| **3 Native** | no Docker · **Windows: Git Bash** · map + shelters, no routing |
| **4 Browser-only** | laptop failed · Pages site · no routing |

<div class="card">

### 🧪 Phase 0 · setup check &nbsp; <span class="small">⏱ 8 min · 🔴 red for >10 min → switch tier</span>

```bash
python setup/check_setup.py
duckdb -c ".read setup/hello-geo.sql"
```

🎯 Same line on every screen: `OK — DuckDB 2.0.0 · 10 shelters (1 verified, 9 candidate) · nearest to Colfax (crow-flies): Sierra Vista Community Center, 0.2 km`

🧯 Still red? Open the Codespaces link on the slide. Codespaces blocked? Open the Pages link and follow along in the browser.

</div>

<!-- S5. 5 min incl. Phase 0 (8 min hands-on). Say: "Three ways to run this. Codespaces needs nothing installed, but launch it from your personal GitHub account. Docker is the one I recommend if you have it, because it keeps working if the wifi dies. Native works without Docker — on Windows use Git Bash — but has no routing. Browser-only is the last resort. If you're red for more than ten minutes, we switch your tier. Codespaces people: sit next to a Docker user, you'll pair for routing if wifi dies. Now run the two commands on the right." Room split geographically between instructors for triage. Checkpoint: same line on every screen — check_setup.py is green/red per tool (go-pmtiles CLI, Java 21, DuckDB 2.0.0, OSRM reachable). -->

---

# What we work with — open data, open tools

| Open datasets | | Open tools | |
|---|---|---|---|
| **OpenStreetMap** | the road network OSRM routes on (`.osm.pbf`, ODbL) | **DuckDB** + spatial | SQL over GeoJSON and Overture's S3 Parquet — pull a county out of the planet in seconds |
| **Overture Maps** | themes: *transportation · places · divisions · base · buildings* — roads, POIs, towns, water, land cover, 3D buildings | **Planetiler → PMTiles** | GeoJSON → vector tiles, one static file, no tile server |
| **CAL FIRE** | Fire Hazard Severity Zones · fire perimeters (ArcGIS services) | **OSRM** | routing graph + `/nearest` `/table` `/route` → nearest shelter by road, reach bands, what-if closures |
| **ESA WorldCover** | land cover (via Overture base) | **MapLibre GL JS** | renders the tiles, three views, routing in the page |

<!-- S6. 1.5 min. Say: "Everything today is open data and open tools. Left column: where the bits of the map come from — OpenStreetMap for the roads we route on, Overture for the roads, places, towns, water and buildings we draw, CAL FIRE for the hazard. Right column: the four tools, one per phase — DuckDB to extract and query, Planetiler to cut tiles, OSRM to route, MapLibre to draw." -->

---

# River Fire, Colfax — August 2021

- Mandatory evacuation **ordered Aug 4**, lifted **~2 days later**
- **2,619 acres**, on the I-80 corridor we map today

> **A real incident on today's corridor — the two questions below are not abstract here.**

<div class="credit">Source: CAL FIRE incident page, fire.ca.gov/incidents/2021/8/4/river-fire · image: assets/img/river-fire-2021.jpg (placeholder)</div>

<!-- S7. 1.5 min. Say: "Why this corridor: the River Fire, August 2021, at Colfax. Mandatory evacuation ordered August 4th, lifted about two days later, 2,619 acres." -->

---

# Mosquito Fire — September 2022

- **76,771 acres** across Placer and El Dorado counties
- The shelter **moved mid-incident**: to **Sierra College, Rocklin** (by Sep 10, 2022)
- The safe place is **not a fixed point**

<div class="credit">Source: Placer County release "Mosquito Fire emergency shelter moves to Sierra College" (placer.ca.gov) · image: assets/img/mosquito-fire-2022.jpg (placeholder)</div>

<!-- S8. 1 min. Say: "The Mosquito Fire, 2022: 76,771 acres. The shelter moved to Sierra College in Rocklin in the middle of the incident. Keep that in mind — the safe place is not a fixed point." -->

---

# Two questions

## 1 · Where are the safe places?
## 2 · How do people reach them in time?

- Today we build a working answer to **both**
- Same data → a **basemap** *and* **routes**

<!-- S9. 1 min. Printed as a handout. Say: "When a wildfire moves toward a town, two questions decide what happens next. Where are the safe places, and how do people reach them in time? By 3 o'clock you'll have a working answer to both." -->

---

# What we leave out

<div class="warn hazard">

- **Shelter status** — open / closed / full
- **Drive time ≠ evacuation time** — OSRM = free-flow, no traffic
- **Live closures** nobody mapped in time
- **Capacity / contraflow**

</div>

> Today's map answers the two questions on a good day. It can't tell you if today is a good day.

<div class="small">Teaching example, not an official evacuation resource. Drive-time estimates assume no traffic and no closures. In an emergency follow county OES / Genasys-Zonehaven alerts and CAL FIRE incident pages.</div>

<!-- S10. 1.5 min. NEVER CUT. Say, slowly: "Today's map answers the two questions on a good day. It can't tell you if today is a good day." Then read the disclaimer at the bottom. -->

---

# Open data + open tools

<div class="two-col">
<div>

### Data
- Overture Maps
- OpenStreetMap
- CAL FIRE FHSZ (CC-BY)

</div>
<div>

### Tools
- DuckDB · Planetiler · PMTiles
- MapLibre GL JS · OSRM
- Marp (these slides)

</div>
</div>

- No accounts, no licences to buy, no server to rent
- You can re-run all of it, on your own laptop

<!-- S11. 1 min. Say: "Everything today is open data and open source. Nothing here needs an account or a licence, and you leave with a repo you can re-run." -->

---

# Study area + the finished app

<div class="two-col">
<div>

**Placer County I-80 corridor**
Rocklin → Auburn → Colfax → Foresthill

bbox `-121.40, 38.72, -120.85, 39.15`

**Demo:**
[vishal4c.github.io/routes-to-safety-workshop/demo/](https://vishal4c.github.io/routes-to-safety-workshop/demo/)

</div>
<div class="imgph">[screenshot: finished demo app]</div>
</div>

> **You build the core of this by 2:37.**

<!-- S12. Live demo 3 min. Say: "This is the finished app: drop a pin, get the nearest shelter by road, toggle I-80 closed. The core of this you build yourselves — routing goes live at 2:05, and you build the core of this by 2:37." Callback later: "At 2:05 you build exactly this." Demo site: https://vishal4c.github.io/routes-to-safety-workshop/demo/ 🧯 If the live demo fails: play the 90-s recorded video. -->
