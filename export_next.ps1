# Incremente build/LesEclatsDeChartres_vNN.exe, met a jour export_presets.cfg, lance l'export Windows.
# Usage: .\export_next.ps1
# Option: $env:GODOT = "C:\chemin\vers\Godot_v4.2-stable_win64_console.exe"

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "build"
$PresetFile = Join-Path $ProjectRoot "export_presets.cfg"
$PresetName = "Windows Desktop"
$BaseName = "LesEclatsDeChartres"

if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }

$maxN = 0
Get-ChildItem -Path $BuildDir -Filter "${BaseName}_v*.exe" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -match '_v(\d+)\.exe$') {
        $n = [int]$Matches[1]
        if ($n -gt $maxN) { $maxN = $n }
    }
}
$next = $maxN + 1
$relPath = "build/${BaseName}_v${next}.exe"
$outFile = Join-Path $ProjectRoot $relPath

Write-Host "Derniere version trouvee dans build: v$maxN -> export v$next -> $relPath"

$cfg = Get-Content -Raw -Path $PresetFile
$cfg2 = $cfg -replace 'export_path="build/LesEclatsDeChartres(_v\d+)?\.exe"', "export_path=`"$relPath`""
if ($cfg2 -eq $cfg) {
    $cfg2 = $cfg -replace 'export_path="build/[^"]+"', "export_path=`"$relPath`""
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($PresetFile, $cfg2.Trim() + "`n", $utf8)

$godot = $env:GODOT
$localConsole = Join-Path $ProjectRoot "godot_bin\Godot_v4.2.2-stable_win64_console.exe"
if (-not $godot -and (Test-Path $localConsole)) {
    $godot = $localConsole
}
if (-not $godot) {
    $candidates = @(
        "$env:ProgramFiles\Godot\Godot_v4.2-stable_win64_console.exe",
        "$env:ProgramFiles\Godot\Godot_v4.3-stable_win64_console.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot*.exe"
    )
    foreach ($c in $candidates) {
        $resolved = Get-Item $c -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($resolved) { $godot = $resolved.FullName; break }
    }
}
if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source }
}

if (-not $godot -or -not (Test-Path $godot)) {
    Write-Host "Godot introuvable. Regle le preset sur: $relPath"
    Write-Host "Export manuel: Godot -> Projet -> Exporter -> Windows Desktop -> Exporter le projet"
    Write-Host "Ou definis: `$env:GODOT = '...\\Godot_*_console.exe' puis relance ce script."
    exit 0
}

Write-Host "Godot: $godot"
& $godot --headless --path $ProjectRoot --export-release $PresetName $outFile
if ($LASTEXITCODE -ne 0) {
    Write-Error "Export echoue (code $LASTEXITCODE)."
    exit $LASTEXITCODE
}
Write-Host "OK: $outFile"
