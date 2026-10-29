# Prep checklist — T-10 … T-0

Workshop: Mon 2026-11-02, 09:00–12:00, room Beavis. Check a box only after you saw the result yourself.
"Measured" = what the build run on an M-series Mac measured on 2026-10-23.

## T-10 days — data and dry runs (OUTLINE §0 prep tasks)

- [x] **(a) Timed dry run** of the Overture fetch and `generate-custom`, with/without land_cover.
  `scripts/fetch-overture.sh` · `01-tiles/build.sh`
  Measured (2026-10-29): fetch **24 s** for all six themes (roads 5 s · water 2 s · towns 0 s · land cover 3 s · buildings 5 s · places 9 s); Planetiler **4 s** → `evac.pmtiles` 7.1 MB. **land_cover kept** (4.2 MB GeoJSON, far below the 10 MB / +30 s limit).
  - [ ] Repeat on a **2-vCPU Codespace** (the numbers above are an M-series Mac).
- [x] **(b) Real OSRM build → per-file sizes.** `scripts/build-osrm.sh` → 15 s, **99 MB** (26 files); `study-area.osm.pbf` 17.0 MB; `colfax.osm.pbf` 0.39 MB.
- [x] **(c) Phase 0 checkpoint string** — real output of `duckdb -c ".read setup/hello-geo.sql"` (2026-10-23): `OK — DuckDB 2.0.0 · 10 shelters (1 verified, 9 candidate) · nearest to Colfax (crow-flies): Sierra Vista Community Center, 0.2 km` (closes OUTLINE §8 attendee #9).
- [x] **(d) arm64 manifest:** OSRM `ghcr.io/project-osrm/osrm-backend:v26.10.0-debian` is multi-arch (used locally on Apple Silicon via Colima). Workshop tool image `ghcr.io/vishal4c/routes-to-safety-workshop:latest` built 2026-10-23 by the devcontainer-image workflow: **amd64 + arm64**, package public.
- [ ] **(e) Caddy smoke test:** `docker compose up -d` then `curl localhost:8080/osrm/nearest/v1/driving/-121.08,38.90` → `"code":"Ok"`. (Direct OSRM already answered on :5000 during the build.)
- [x] **(f) Shallow clone size:** `git clone --depth 1 https://github.com/vishal4c/routes-to-safety-workshop.git` → **38 MB transferred (.git), 109 MB on disk, 3 s** (measured 2026-10-23, home wifi). `check_setup.py` passes in the fresh clone; pmtiles/osrm correctly reported as optional → `scripts/get-bundle.sh`.
- [ ] **(g) Clean-machine rehearsal:** Windows 11 (Git Bash **and** PowerShell) and macOS: tier 3 from scratch, `python3 setup/check_setup.py`, Phase 1a–1c.
- [ ] **Finch rehearsal** (recommended runtime on corporate laptops): `finch vm init && finch compose up`, then `scripts/build-osrm.sh`; confirm `detect_container_cli` picks it up.
- [ ] **(h) 90-second demo video** (live-demo fallback for Phase 0) recorded; file on the laptop *and* the USB sticks.
- [x] **(i) Coverage precomputed:** `scripts/make-coverage.py` → 3,341 hexes, 30 bands. Re-run after any shelter change.
- [ ] `shasum -a 256 -c data/CHECKSUMS.sha256` passes on a fresh checkout + bundle.
- [ ] `scripts/check-versions.sh` clean (no drift from `versions.env`).

## T-7 — publish

- [ ] ghcr devcontainer image pushed (personal account `vishal4c`); Codespaces prebuild green.
- [ ] GitHub Pages live: slides + `02-web/` + `prebuilt/evac.pmtiles` + demo site. Open it from a phone.
- [ ] Release asset `data-bundle.zip` uploaded; `scripts/get-bundle.sh` downloads and verifies it.
- [ ] Setup email drafted (Vishal reviews/sends) — **comms channel still unconfirmed** (OUTLINE §8 instructor #1): ask FOSS4G NA organizers which channel reaches registrants; ask for room wifi capacity.
- [ ] Demo video on Pages.

## T-3 / T-2

- [ ] T-3: clean-machine rehearsal repeated from the *published* repo (not your working copy).
- [ ] T-2: re-verify ghcr image, Codespaces prebuild and Pages after any push. `git log` squashed before the final pin.
- [ ] **USB sticks** (≥ 4, 16 GB+, exFAT): repo zip · `data-bundle.zip` · installers (DuckDB 2.0.0, Temurin 21, Node 22, go-pmtiles 1.31.2, Git for Windows, Finch/Docker installer for the room's OS mix) · `CHECKSUMS.sha256` · the 90-s demo video · a printed-QR copy of the Pages URL. Test one stick on a clean Windows laptop.
- [ ] Print: **S4 pipeline picture** and **S9 two questions** handouts (≈ 35 copies), door sign with QR ("Sit down → start your Codespace or `docker compose pull` now"), green/red sticky notes, a red card (cut signal).

## T-1

- [ ] Reminder email sent. Phone/laptop chargers, HDMI + USB-C dongles, a spare laptop pre-pulled (tier 2).
- [ ] Pre-pull on the instructor laptops: `docker compose pull` (or `finch compose pull`), `docker compose up -d`, `curl localhost:8080/osrm/nearest/v1/driving/-121.08,38.90`.
- [ ] Slides exported to PDF + PPTX as well as HTML; copy on the stick.

## T-0 — day of

- [ ] **T-0:30 AV test in room Beavis:** projector resolution and font size from the back row; clicker; both instructors' mic; open the Pages URL on the room wifi; run `duckdb -c ".read setup/hello-geo.sql"` projected.
- [ ] Ask the room for the **wifi capacity** and the guest password; write both on the door slide.
- [ ] Door slide up before 09:00; Codespaces users seated next to Docker users (seat map for the pairing rule).
- [ ] A/B roles assigned, B has the timer and red card. Hard-stop cut order printed: Phase 4 live part → Phase 3c finish-early → Phase 3a optional parts → S35/S37.
- [ ] Local OSRM running on the instructor laptop (for the demo and for narrated build). **Do not** forward port 5000 in Codespaces.

## Regenerate the data and the bundle (instructor)

Every step reads `versions.env`. From the repo root, in the tool container unless noted:

```bash
scripts/fetch-overture.sh                      # data/overture/*.geojson  (24 s for the Placer box)
scripts/fetch-hazard.sh                        # data/hazard/*.geojson    (CAL FIRE)
scripts/fetch-osm.sh                           # data/osm/study-area.osm.pbf  (downloads norcal-latest, ~1 GB, once)
osmium extract --overwrite -b -121.02,39.05,-120.90,39.13 -s smart -o data/osm/colfax.osm.pbf data/osm/study-area.osm.pbf   # Phase 2b demo clip
scripts/build-osrm.sh                          # data/osrm/  — laptop terminal (needs Docker) or Codespaces
docker compose restart osrm                    # laptop terminal
scripts/make-coverage.py --osrm http://osrm:5000   # data/coverage/*.geojson
01-tiles/build.sh && cp out/evac.pmtiles data/prebuilt/evac.pmtiles
scripts/make-bundle.sh                         # dist/data-bundle.zip + CHECKSUMS.sha256 (then: cp the CHECKSUMS into data/)
gh release upload data-v2 dist/data-bundle.zip --clobber    # or: gh release create data-v2 dist/data-bundle.zip
```
Bump the tag (`data-v3` …) in `scripts/get-bundle.sh`, `scripts/get-bundle.ps1`, `docker-compose.yml`, `.github/workflows/pages.yml` when the bundle's contents change in a way old clones must pick up; `get-bundle.sh` re-downloads whenever the files on disk stop matching `data/CHECKSUMS.sha256`.

## Slides (Marp)

Theme `slides/theme.css` (`@theme rts`), Marp CLI pinned to **4.5.1**; `.marprc.yml` at the repo root sets `html: true` and the theme. Input file first — `--theme-set` swallows positional arguments.

```bash
npx @marp-team/marp-cli@4.5.1 slides/00-overview.md --html --theme-set slides/theme.css -o out/00-overview.html
npx @marp-team/marp-cli@4.5.1 slides/00-overview.md --html --pdf --allow-local-files --theme-set slides/theme.css -o out/00-overview.pdf   # needs Chrome
npx @marp-team/marp-cli@4.5.1 --theme-set slides/theme.css -s slides/      # live preview
```

| Deck | Slides | Phase |
|---|---|---|
| `00-overview.md` | door + S1–S12 | Phase 0 — setup, welcome, the problem and the plan |
| `02-data.md` | S13–S19 | Phase 1 — data prep |
| `03-tiles.md` | S20–S26 | Phase 2 → 3 — tiles, routing graph, the map |
| `04-routing.md` | S27–S31 | Phase 3c — routing |
| `05-adapt.md` | S32–S37 | Phase 4 — adapt |
| `09-close.md` | S38–S41 | close |

`notes/cue-sheet.md` is the instructor cue sheet; `IMAGE-CREDITS.md` lists the image sources. The Pages workflow builds every deck to HTML + PDF.
