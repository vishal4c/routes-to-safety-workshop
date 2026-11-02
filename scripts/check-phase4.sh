#!/usr/bin/env bash
# Phase 4 — check that every output describes the box in versions.env: Overture data, shelters, the routing graph OSRM
# is serving, the tiles, the reach bands and the web server. One line per check; a red line names the step to redo.
#
#   scripts/check-phase4.sh          run in the container shell (option C: export OSRM_URL and WEB_URL first)
. "$(dirname "$0")/lib.sh"
set +e   # a checker: keep going after a failed check
need duckdb; need curl; need python3
cd "$REPO_ROOT"
OSRM_URL="${OSRM_URL:-http://localhost:8080/osrm}"; WEB_URL="${WEB_URL:-http://localhost:8080}"
fails=0
ok()   { printf '\033[1;32m  OK \033[0m %-24s %s\n' "$1" "$2"; }
bad()  { printf '\033[1;31mFAIL \033[0m %-24s %s\n' "$1" "$2"; fails=$((fails + 1)); }
q()    { duckdb -noheader -csv -c "LOAD spatial; SET geometry_always_xy = true; $1" 2>/dev/null; }
IN_BOX="ST_X(geom) BETWEEN $BBOX_W AND $BBOX_E AND ST_Y(geom) BETWEEN $BBOX_S AND $BBOX_N"
echo "box (versions.env): $BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N"

# 1 · Overture roads, inside the box
if [ -f data/overture/roads.geojson ]; then
  read -r n cx cy <<<"$(q "SELECT count(*), round(avg(ST_X(ST_Centroid(geom))),3), round(avg(ST_Y(ST_Centroid(geom))),3) FROM ST_Read('data/overture/roads.geojson')" | tr ',' ' ')"
  if [ "${n:-0}" -gt 1 ] && python3 -c "import sys; x,y=float('$cx'),float('$cy'); sys.exit(not($BBOX_W<=x<=$BBOX_E and $BBOX_S<=y<=$BBOX_N))"; then
    ok "overture roads" "$n segments, centred inside the box"
  else bad "overture roads" "${n:-0} segments, centre $cx,$cy — not this box: step 2 (scripts/fetch-overture.sh)"; fi
else bad "overture roads" "data/overture/roads.geojson missing — step 2 (scripts/fetch-overture.sh)"; fi

# 2 · hazard layers exist (empty is fine outside California)
if [ -f data/hazard/fhsz.geojson ] && [ -f data/hazard/fire_perimeters.geojson ]; then ok "hazard" "both files present"
else bad "hazard" "missing — step 3 (scripts/fetch-hazard.sh, or --none outside California)"; fi

# 3 · shelters: more than zero, all inside the box
if [ -f data/shelters.geojson ]; then
  read -r n inside <<<"$(q "SELECT count(*), count(*) FILTER ($IN_BOX) FROM ST_Read('data/shelters.geojson')" | tr ',' ' ')"
  if [ "${n:-0}" -eq 0 ]; then bad "shelters" "0 shelters — step 4 (scripts/pick-shelters.sh with ids from out/shelter-candidates.csv)"
  elif [ "$inside" != "$n" ]; then bad "shelters" "$((n - inside)) of $n outside the box — step 4"
  else ok "shelters" "$n, all inside the box"; fi
else bad "shelters" "data/shelters.geojson missing — step 4"; fi

# 4 · OSRM serves a graph for this box: the box centre and every shelter snap to a road nearby
snap() { curl -s --max-time 10 "$OSRM_URL/nearest/v1/driving/$1,$2" | python3 -c "import json,sys; d=json.load(sys.stdin); print(round(d['waypoints'][0]['distance']) if d.get('code')=='Ok' else -1)" 2>/dev/null || echo -1; }
cx=$(python3 -c "print(($BBOX_W+$BBOX_E)/2)"); cy=$(python3 -c "print(($BBOX_S+$BBOX_N)/2)")
d=$(snap "$cx" "$cy")
if [ "$d" = -1 ]; then bad "osrm" "no answer at $OSRM_URL — docker compose up -d (laptop terminal)"
elif [ "$d" -gt 5000 ]; then bad "osrm" "box centre snaps to a road $((d / 1000)) km away: OSRM still serves the old graph — step 5 (build-osrm.sh, then restart osrm)"
else
  far=""
  if [ -f data/shelters.geojson ]; then
    while IFS=, read -r name x y; do
      [ -n "$x" ] || continue
      s=$(snap "$x" "$y"); [ "$s" -ge 0 ] && [ "$s" -le 2000 ] || far="$far $name(${s} m)"
    done <<<"$(q "SELECT replace(name, ',', ' '), ST_X(geom), ST_Y(geom) FROM ST_Read('data/shelters.geojson')")"
  fi
  if [ -n "$far" ]; then bad "osrm" "box centre ${d} m from a road, but shelters far from any road:$far — step 4 or 5"
  else ok "osrm" "box centre ${d} m from a road; every shelter within 2 km"; fi
fi

# 5 · tiles: a complete PMTiles archive whose bounds are the box
if [ -f out/evac.pmtiles ]; then
  if [ "$(head -c 7 out/evac.pmtiles)" != "PMTiles" ]; then bad "tiles" "out/evac.pmtiles is not a PMTiles archive (half-written?) — step 6 (01-tiles/build.sh)"
  else
    b=$(pmtiles show out/evac.pmtiles 2>/dev/null | python3 -c "
import re,sys; m=re.search(r'bounds: \(long: (-?[0-9.]+), lat: (-?[0-9.]+)\) \(long: (-?[0-9.]+), lat: (-?[0-9.]+)\)', sys.stdin.read())
v=[float(x) for x in m.groups()]; w=[$BBOX_W,$BBOX_S,$BBOX_E,$BBOX_N]
print('same' if all(abs(a-c)<0.01 for a,c in zip(v,w)) else ','.join('%g' % x for x in v))" 2>/dev/null)
    if [ "$b" = same ]; then ok "tiles" "out/evac.pmtiles bounds = the box"
    elif [ -z "$b" ]; then bad "tiles" "pmtiles show could not read out/evac.pmtiles — step 6"
    else bad "tiles" "out/evac.pmtiles covers $b, not the box — step 6 (01-tiles/build.sh)"; fi
  fi
else bad "tiles" "out/evac.pmtiles missing — step 6 (01-tiles/build.sh)"; fi

# 6 · reach bands made for the current shelters (every band belongs to a shelter in data/shelters.geojson)
if [ -f data/coverage/coverage_bands.geojson ]; then
  stale=$(q "SELECT count(*) FROM ST_Read('data/coverage/coverage_bands.geojson') WHERE shelter_id NOT IN (SELECT id FROM ST_Read('data/shelters.geojson'))")
  if [ "${stale:-1}" != 0 ]; then
    bad "reach bands" "$stale rings belong to shelters that are no longer in data/shelters.geojson — step 7 (scripts/make-coverage.py --osrm http://osrm:5000)"
  else ok "reach bands" "$(q "SELECT count(*) FROM ST_Read('data/coverage/coverage_bands.geojson')") rings, all for current shelters"; fi
else bad "reach bands" "data/coverage/coverage_bands.geojson missing — step 7"; fi

# 7 · the web server answers Range requests with the same archive
hdr=$(curl -s --max-time 10 -D - -o /tmp/rts-range.$$ -H 'Range: bytes=0-15' "$WEB_URL/out/evac.pmtiles" | head -1 | tr -d '\r')
if [[ "$hdr" == *" 206"* ]] && [ "$(head -c 7 /tmp/rts-range.$$)" = PMTiles ]; then ok "web server" "$WEB_URL answers 206 with a PMTiles header"
elif [ -z "$hdr" ]; then bad "web server" "no answer at $WEB_URL — docker compose up -d (laptop terminal), or npx serve -l 8080 . (option C)"
elif [[ "$hdr" == *" 206"* ]]; then bad "web server" "Range works, but the bytes served are not a PMTiles header — step 6 (01-tiles/build.sh), then hard-refresh the page"
else bad "web server" "$WEB_URL/out/evac.pmtiles → '$hdr', needs 206 Partial Content: serve with Caddy or npx serve (troubleshooting/phase4.md)"; fi
rm -f /tmp/rts-range.$$

[ "$fails" -eq 0 ] && echo "All Phase 4 checks passed." || { echo "$fails check(s) failed — fix the first red line, then run this again (more: troubleshooting/phase4.md)."; exit 1; }
