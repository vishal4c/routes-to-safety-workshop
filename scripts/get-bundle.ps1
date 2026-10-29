# PowerShell version of scripts/get-bundle.sh. Run from anywhere:  powershell -ExecutionPolicy Bypass -File scripts\get-bundle.ps1
# Offline / USB: $env:BUNDLE_ZIP = "E:\data-bundle.zip"
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
Set-Location $Repo
$Tag = if ($env:BUNDLE_TAG) { $env:BUNDLE_TAG } else { 'data-v2' }
$Url = "https://github.com/vishal4c/routes-to-safety-workshop/releases/download/$Tag/data-bundle.zip"
New-Item -ItemType Directory -Force dist, data | Out-Null

$complete = (Test-Path data/prebuilt/evac.pmtiles) -and (Test-Path data/osrm/study-area.osrm.mldgr) -and (Test-Path 01-tiles/planetiler.jar) -and (Test-Path data/osm)
if ($complete -and $env:FORCE -ne '1') {
  Write-Host 'Bundle already in place (set $env:FORCE=1 to re-download).'
} else {
  $Zip = if ($env:BUNDLE_ZIP) { $env:BUNDLE_ZIP } else { 'dist/data-bundle.zip' }
  if (-not (Test-Path $Zip)) {
    Write-Host "Downloading $Url"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $Zip
  }
  $Stage = Join-Path ([IO.Path]::GetTempPath()) ("rts-bundle-" + [guid]::NewGuid())
  Expand-Archive -Path $Zip -DestinationPath $Stage -Force
  $Sums = Join-Path $Stage 'CHECKSUMS.sha256'
  if (-not (Test-Path $Sums)) { throw 'CHECKSUMS.sha256 missing in bundle' }
  Write-Host 'Verifying checksums...'
  foreach ($line in Get-Content $Sums) {
    if ($line -match '^([0-9a-fA-F]{64})\s+\*?(.+)$') {
      $want = $Matches[1].ToLower(); $rel = $Matches[2]
      $got = (Get-FileHash -Algorithm SHA256 (Join-Path $Stage $rel)).Hash.ToLower()
      if ($got -ne $want) { throw "Checksum mismatch: $rel" }
    }
  }
  Write-Host 'Checksums OK. Installing...'
  New-Item -ItemType Directory -Force data/prebuilt, 01-tiles | Out-Null
  foreach ($d in 'osm','osrm') {
    $src = Join-Path $Stage "data/$d"
    if (Test-Path $src) { New-Item -ItemType Directory -Force "data/$d" | Out-Null; Copy-Item "$src/*" "data/$d" -Recurse -Force }
  }
  $p = Join-Path $Stage 'data/prebuilt/evac.pmtiles'; if (Test-Path $p) { Copy-Item $p data/prebuilt/ -Force }
  $j = Join-Path $Stage '01-tiles/planetiler.jar';   if (Test-Path $j) { Copy-Item $j 01-tiles/ -Force }
  Copy-Item $Sums data/CHECKSUMS.sha256 -Force
  Remove-Item $Stage -Recurse -Force
}
Write-Host 'Sizes:'
foreach ($p in 'data/osm','data/osrm','data/prebuilt/evac.pmtiles','01-tiles/planetiler.jar') {
  if (Test-Path $p) {
    $mb = (Get-ChildItem $p -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
    '{0,8:N1} MB  {1}' -f $mb, $p
  }
}
