# Phase 2a (PowerShell) — build out/evac.pmtiles from the GeoJSON in data/ (Overture themes, hazard, shelters).
#   01-tiles\build.ps1
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root
$env = Get-Content versions.env | Where-Object { $_ -match '^\s*[A-Z_]+=' } | ForEach-Object { $k,$v = $_ -split '=',2; @{ $k = $v } }
$V = @{}; $env | ForEach-Object { $V += $_ }
$Jar = "01-tiles\planetiler.jar"
if (-not (Test-Path $Jar)) { Invoke-WebRequest "https://github.com/onthegomap/planetiler/releases/download/v$($V.PLANETILER_VERSION)/planetiler.jar" -OutFile $Jar }
foreach ($f in "data\overture\roads.geojson","data\overture\water.geojson","data\overture\towns.geojson","data\overture\land_cover.geojson","data\overture\buildings.geojson") {
  if (-not (Test-Path $f)) { throw "$f missing — run scripts/fetch-overture.sh (Git Bash)" }
}
foreach ($f in "data\hazard\fhsz.geojson","data\hazard\fire_perimeters.geojson") {
  if (-not (Test-Path $f)) { throw "$f missing — run scripts/fetch-hazard.sh or scripts/fetch-hazard.sh --none (Git Bash)" }
}
if (-not (Test-Path "data\shelters.geojson")) { throw "data/shelters.geojson missing" }
# zero features (a Phase 4 pick that matched nothing) would crash Planetiler's reader → one placeholder shelter at the box's south-west corner (same as scripts/lib.sh)
if ((Get-Content "data\shelters.geojson" -Raw | ConvertFrom-Json).features.Count -eq 0) {
  $ph = '{"type":"FeatureCollection","name":"shelters","features":[{"type":"Feature","properties":{"id":"placeholder","name":"Placeholder shelter (no shelter picked)","status":"candidate","type":"placeholder","town":"","source":"placeholder at the south-west corner of the box in versions.env - no shelter picked yet; replace with real shelters (scripts/pick-shelters.sh)"},"geometry":{"type":"Point","coordinates":[' + $V.BBOX_W + ',' + $V.BBOX_S + ']}}]}'
  Set-Content -Path "data\shelters.geojson" -Value $ph -Encoding UTF8
  Write-Host "no shelters -> data/shelters.geojson is one placeholder at the box's south-west corner ($($V.BBOX_W), $($V.BBOX_S)); replace it: scripts/pick-shelters.sh <id> ..."
}
New-Item -ItemType Directory -Force out | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew()
java -Xmx2g -jar $Jar generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force `
  --bounds="$($V.BBOX_W),$($V.BBOX_S),$($V.BBOX_E),$($V.BBOX_N)" --minzoom=4 --maxzoom=14
Write-Host ("built out/evac.pmtiles in {0}s ({1:N1} MB)" -f [int]$sw.Elapsed.TotalSeconds, ((Get-Item out\evac.pmtiles).Length/1MB))
