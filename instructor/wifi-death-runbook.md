# Wifi-death runbook (one page)

Trigger: pages don't load, Codespaces disconnect, `docker compose pull` stalls — **any minute**. B calls it; A says the line.

## Before (the stagger — said at S1, during the title slide)
> "Start your Codespace — or `docker compose pull` — right now as you sit down. Don't wait for me."

- [ ] Codespaces users sit next to Docker users (announced at S5; this is the pairing seat map).
- [ ] Room wifi capacity requested from organizers; ≥ 4 USB sticks ready.

## When wifi dies
1. **Say** (A): "Wifi's gone. That's fine — tiers 2 and 3 keep working. If you're on Codespaces or the browser site, turn to a neighbor with Docker or a native install and pair up."
2. **Tiers 2–3 continue** — everything they need is local: repo, bundle, pre-pulled images, `npx serve`. Nothing in the hands-on phases needs the network except tier 1/4 and the public OSRM fallback.
3. **Pairing** (B walks the room): one driver, one navigator, swap at each phase card. Tier 3 (no routing) pairs with a Docker neighbor for Phase 3c.
4. **Narrated build** (A): switch to the instructor laptop (pre-pulled, local OSRM) and run the current phase card on the projector while attendees follow on screen. Say: "I'll drive, you watch the numbers — they're the ones on your card."
5. **USB sticks** circulate (B): repo zip + `data-bundle.zip` + installers + checksums. Say: "Copy the folder, unzip it, run `python3 setup/check_setup.py`." Verify with `shasum -a 256 -c data/CHECKSUMS.sha256`.
6. **Phase fallbacks stay valid offline:** Phase 1 → `cp data/prebuilt/out/* out/` · Phase 2 → 3 → `cp data/prebuilt/evac.pmtiles out/` · Phase 3c → `steps/step3-solution.js`.
7. **Tell the room when it's back:** "Wifi's back — if you paired, stay paired for this block."

## Scripted lines (🧯)
| Where | Line |
|---|---|
| Phase 0 still red | "Open the Codespaces link on the slide. Codespaces blocked? Open the Pages link and follow along in the browser." |
| Phase 1 behind | "Copy `data/prebuilt/out/` into `out/` and catch up at the next card." |
| Phase 2a behind | "No PMTiles by minute 5 → `cp data/prebuilt/evac.pmtiles out/`." |
| Phase 3a stuck | "Past minute 8? Paste `steps/step3-styled.json`." |
| Phase 3c, tiers 3/4 | "Routing needs Docker or Codespaces. Pair with a neighbor, or follow the screen — map and shelters still work." |
| Phase 3c step 2 stuck | "Not routing by minute 6 → open `steps/step3-solution.js`." |
| Cut signal | B raises the red card; A: "We'll pick this up in the repo." and advances to the next card. |
| Live demo fails | Play the 90-second recorded video. |

## Don'ts
- Don't forward port 5000 in Codespaces (private-port auth wall) — use the Caddy `/osrm` path.
- Don't use `python -m http.server` (no Range requests; PMTiles fails).
- Don't let the break shrink below 5 min; never cut S10, S31 or the close.
