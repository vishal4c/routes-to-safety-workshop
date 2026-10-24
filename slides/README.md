# Slides (Marp)

Theme: `slides/theme.css` (`@theme rts`). Marp CLI pinned: **4.5.1**. Front-matter in every deck: `marp: true`, `theme: rts`, `paginate: true`, `footer: Routes to Safety · FOSS4G NA 2026`, `size: 16:9`.

```bash
# HTML (raw HTML in slides needs --html, or the .marprc.yml next to this repo root which sets html: true)
npx @marp-team/marp-cli@4.5.1 --theme-set slides/theme.css slides/00-overview.md --html -o out/00-overview.html
# PDF / PPTX (PDF needs Chrome/Chromium installed)
npx @marp-team/marp-cli@4.5.1 --theme-set slides/theme.css slides/00-overview.md --pdf  -o out/00-overview.pdf
npx @marp-team/marp-cli@4.5.1 --theme-set slides/theme.css slides/00-overview.md --pptx -o out/00-overview.pptx
# live preview
npx @marp-team/marp-cli@4.5.1 --theme-set slides/theme.css -s slides/
```
Add `--allow-local-files` for PDF/PPTX if images under `assets/img/` are referenced.
Image paths in decks are `../assets/img/<file>`; the files do not exist yet (see `IMAGE-CREDITS.md`) — placeholders are shown instead.

## Decks

| File | Slides | Block |
|---|---|---|
| `00-overview.md` | door + S1–S12 (13 pages) | Block 0 (setup & welcome) + Block 1 (problem & plan) |
| `01-data.md` | S13–S19 | Block 2 (other agent) |
| `02-tiles.md` | S20–S26 | Block 3 (other agent) |
| `03-routing.md` | S27–S31 | Block 4 (other agent) |
| `04-adapt.md` | S32–S37 | Block 5 (other agent) |
| `09-close.md` | S38–S41 | Block 5 close |

Other files: `notes/cue-sheet.md` (instructor), `IMAGE-CREDITS.md`.

`--html` is required (decks use `<div class="two-col">` etc.). A `.marprc.yml` (`html: true`, `theme-set: slides/theme.css`) at the repo root does the same. Put the input file first: `--theme-set` swallows positional args.
