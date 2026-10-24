---
marp: true
theme: rts
paginate: true
footer: Routes to Safety · FOSS4G NA 2026
size: 16:9
---

# Recap — the pipeline you built

```text
Overture + OSM ─► DuckDB ─► GeoJSON ─► Planetiler ─► PMTiles ─► MapLibre
                  (Phase 1)   out/*.geojson  (Phase 2a)   evac.pmtiles  (Phase 3a–b)
                                                                      ▲
                        OSRM graph ─► /table · /route · /nearest ─────┘  (Phase 3c)
```

- **Extract** with spatial SQL · **Tile** with Planetiler · **Render** with MapLibre · **Route** with OSRM
- Then: pin versions, swap the community (Phase 4 `--plan`)
- Remember: it answers the two questions **on a good day**

<!-- S38. 1.5 min. Say: "Here's the picture from the start, now filled in. Each arrow is something you ran. One extract became both a basemap and routes — and it only answers the questions on a good day." -->

---

# Licenses & attribution

| What | License |
|---|---|
| Code | MIT |
| Materials (slides, docs) | CC BY-SA 4.0 |
| OpenStreetMap | ODbL |
| Overture Maps | ODbL / CDLA-Permissive (by theme) |
| CAL FIRE FHSZ | CC-BY |
| ESA WorldCover | CC-BY |

Details: `data/LICENSE-data.md`

<div class="small">© OpenStreetMap contributors · © Overture Maps Foundation · Fire Hazard Severity Zones: CAL FIRE FRAP (CC-BY) · Land cover: ESA WorldCover (CC-BY)</div>

<!-- S39. 0.5 min. Say: "Code is MIT, materials CC BY-SA. Data licences differ by source — if you publish a map, keep the attribution string on it." -->

---

# Feedback + links

<div class="two-col">
<div class="imgph">[QR placeholder: feedback form]</div>
<div>

- **Repo:** github.com/vishal4c/routes-to-safety-workshop
- **Demo:** vishal4c.github.io/routes-to-safety-workshop/demo/
- Feedback form: [URL placeholder]

</div>
</div>

<!-- S40. 1 min. Say: "Please scan this and tell us what worked and what didn't. The repo has everything, including the stretch exercises and the solutions." -->

---
<!-- _class: lead -->

# Thank you

## Vishal Kumar · Shaishav Maisuria

Questions → stay, or find us in the hallway

<div class="small">Teaching example, not an official evacuation resource.</div>

<!-- S41. 1 min. Say: "Thank you. Stay for questions." -->
