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
New-Item -ItemType Directory -Force out | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew()
java -Xmx2g -jar $Jar generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force `
  --bounds="$($V.BBOX_W),$($V.BBOX_S),$($V.BBOX_E),$($V.BBOX_N)" --minzoom=4 --maxzoom=14
Write-Host ("built out/evac.pmtiles in {0}s ({1:N1} MB)" -f [int]$sw.Elapsed.TotalSeconds, ((Get-Item out\evac.pmtiles).Length/1MB))
