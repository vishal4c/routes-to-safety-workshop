# Instructor cue sheet — Routes to Safety (Mon Nov 2 2026, 09:00–12:00, room Beavis)

## Choreography (default — adjust with Shaishav)
- **A** narrates; **B** is on the floor from minute 1 of every phase. **Swap A/B at every phase boundary.**
- **B is timekeeper** with a visible countdown. **Cut signal: B raises a red card → A says "we'll pick this up in the repo" and advances to the next phase card.**
- 👀 2-min "pens down" regroup after every sub-phase (budgeted as "+2" in each phase).
- Phase 0: room split geographically between instructors for triage.

## Time budget
15 + 15 + 40 + 10 + 45 + 32 + 23 = 180. Phase 0 = 5 + 8 + 2; Phase 0 = 9 + 3 + 3 slack.
Start 0:00 · B1 0:15 · B2 0:30 · Break 1:10 · B3 1:20 · B4 2:05 · B5 2:37 · End 3:00.

## Hard-stop cut order
1. Phase 4 live part → 2. Phase 3c finish-early stretch → 3. Phase 3a optional parts → 4. S35/S37.
**Never cut:** S10 (what we leave out), S31 (reproducibility), the close.

## Break
May compress to 5 min, never below.

## Staggered start
Door slide before 09:00: "start your Codespace / `docker compose pull` as you sit down, during the title slide." Codespaces users sit next to Docker users (announce at S5). Ask organizers for room wifi capacity (wifi confirmed available; capacity unconfirmed).

## Wifi-death runbook (any minute)
- Tiers 2–3 continue offline.
- Tier 1/4 attendees pair with a tier-2/3 neighbour (seat pairing from S5).
- Instructor A switches to a narrated build on the local pre-pulled laptop.
- USB sticks (repo + bundle + installers) circulate.
- Don't let anyone forward port 5000 in Codespaces (private-port auth wall) — use the Caddy path (`/osrm`).

## Callbacks
- S12 demo (3 min): "At 2:05 you build exactly this." Fallback: 90-s recorded video.
- S3 agenda shows 2:05 routing / 2:37 adapt.
- S10 line, verbatim: "Today's map answers the two questions on a good day. It can't tell you if today is a good day."

## Scripted 🧯 lines (OUTLINE §1)

| Block | Trigger | Exact line |
|---|---|---|
| 0 Phase 0 | Check still red | "Still red? Open the Codespaces link on the slide. Codespaces blocked? Open the Pages link and follow along in the browser." |
| 1 Demo | Live demo fails | Play the 90-s recorded video (no scripted line in outline) |
| 2 Phase 1b | Attendees see the Chevrolet dealer tagged `community_center` | "this is exactly why shelters.geojson is hand-verified and carries a `status`; at real scale somebody still has to check" (teaching line, not a fallback) |
| 2 Phase 1c | Not done by minute 5 | `cp data/prebuilt/out/* out/` |
| 2 general | Behind | "Copy `data/prebuilt/out/` into `out/` and catch up at the next card." |
| 3 Phase 2a | No PMTiles by minute 5 | `cp data/prebuilt/evac.pmtiles out/` |
| 3 Phase 3a | Stuck past minute 8 | paste `steps/step3-styled.json` |
| 3 general | Behind | `data/prebuilt/evac.pmtiles` · `steps/step1..4` · instructor Maputnik via `pmtiles serve` ZXY (no scripted line in outline) |
| 4 Phase 3c step 2 | Not routing by minute 6 | open `steps/step3-solution.js` |
| 4 Phase 3c step 3 | Closure question | "Real closures aren't a parameter — nobody flags a downed power line before you drive into it. This shows the calculation, not detection." |
| 4 general | Tier 3/4 attendee (no routing by design) | Pair with a Docker/Codespaces neighbour or follow the screen (card says so); `steps/step3-solution.js`; Pages demo (map + shelters) |
| 4 finish-early stretch | Cut / overrun | Card says: "finish at home — the repo has the solution" |
| 5 Phase 4 | Wants the real run | Real run is homework (card says so); `make-data.sh --plan` works offline |
| 5 S34 | Going-live discussion | Caveat: going live raises the stakes on every S10 caveat |
| Any | Red card cut | "we'll pick this up in the repo" |

Note: outline gives full spoken text only for the quoted lines; rows marked "no scripted line" are instructor actions from the outline.

## Open items (OUTLINE §8)
- Phase 0 checkpoint string (verified 2026-10-23): `OK — DuckDB 2.0.0 · 10 shelters (1 verified, 9 candidate) · nearest to Colfax (crow-flies): Sierra Vista Community Center, 0.2 km`
- Attendee-comms channel unconfirmed (action item Q7).
