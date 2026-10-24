# Phase 2a (PowerShell) — build out/evac.pmtiles from the GeoJSON exported in Phase 1c.
#   01-tiles\build.ps1              uses out\*.geojson
#   01-tiles\build.ps1 -Prebuilt    uses data\prebuilt\out\*.geojson (fallback)
param([switch]$Prebuilt)
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root
$env = Get-Content versions.env | Where-Object { $_ -match '^\s*[A-Z_]+=' } | ForEach-Object { $k,$v = $_ -split '=',2; @{ $k = $v } }
$V = @{}; $env | ForEach-Object { $V += $_ }
$Jar = "01-tiles\planetiler.jar"
if (-not (Test-Path $Jar)) { Invoke-WebRequest "https://github.com/onthegomap/planetiler/releases/download/v$($V.PLANETILER_VERSION)/planetiler.jar" -OutFile $Jar }
if ($Prebuilt) { New-Item -ItemType Directory -Force out | Out-Null; Copy-Item data\prebuilt\out\*.geojson out\ }
if (-not (Test-Path out\roads.geojson)) { throw "out\roads.geojson missing — run Phase 1c first, or pass -Prebuilt" }
$sw = [Diagnostics.Stopwatch]::StartNew()
java -Xmx2g -jar $Jar generate-custom --schema=01-tiles/evac.yml --output=out/evac.pmtiles --force `
  --bounds="$($V.BBOX_W),$($V.BBOX_S),$($V.BBOX_E),$($V.BBOX_N)" --minzoom=4 --maxzoom=14
Write-Host ("built out/evac.pmtiles in {0}s ({1:N1} MB)" -f [int]$sw.Elapsed.TotalSeconds, ((Get-Item out\evac.pmtiles).Length/1MB))
