#!/usr/bin/env bash
# Phase 1 · Fetch, offline: copy the committed GeoJSON in staged_data/ into data/ (same files and counts as
# scripts/fetch-overture.sh + scripts/fetch-hazard.sh for the Placer box). No network. Safe to re-run.
#
#   scripts/stage-data.sh
. "$(dirname "$0")/lib.sh"
SRC="$REPO_ROOT/staged_data"
is_placer_box || log "note: versions.env holds another box; staged_data/ is the Placer box"
for d in overture hazard; do
  mkdir -p "$REPO_ROOT/data/$d"
  for f in "$SRC/$d"/*.geojson; do
    [ -f "$f" ] || die "$SRC/$d has no GeoJSON — re-clone, or run scripts/fetch-$d.sh"
    cp "$f" "$REPO_ROOT/data/$d/"
    n="?"; command -v python3 >/dev/null 2>&1 && n="$(count_features "$f")"
    log "data/$d/$(basename "$f"): $n features"
  done
done
log "next: duckdb -c \".read 00-data/01-explore.sql\""
