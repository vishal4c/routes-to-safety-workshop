# Glyphs (fonts) for map labels

MapLibre renders text from signed-distance-field glyph PBFs, requested per 256-codepoint range.
These are **Noto Sans** Regular + Medium, ranges `0-255` and `256-511` (Latin), copied from
<https://github.com/protomaps/basemaps-assets> so labels work **offline in the room**.

Noto Sans is licensed under the SIL Open Font License 1.1. Add more ranges (e.g. `512-767`) from the same
source if you render non-Latin names. Referenced from `index.html` as `glyphs: <page dir>/fonts/{fontstack}/{range}.pbf`.
