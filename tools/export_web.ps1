# Export Mentchik The Story for browser, sync to web/ (Vercel root via GitHub).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Godot = Join-Path $Root "godot_bin\Godot_v4.2.2-stable_win64_console.exe"
$BuildDir = Join-Path $Root "build\web"
$WebDir = Join-Path $Root "web"
$OutHtml = Join-Path $BuildDir "index.html"

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
& $Godot --headless --path $Root --export-release "Web" $OutHtml
if ($LASTEXITCODE -ne 0) { throw "Godot web export failed ($LASTEXITCODE)" }

if (Test-Path $WebDir) { Remove-Item $WebDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $WebDir | Out-Null
Copy-Item (Join-Path $BuildDir "*") -Destination $WebDir -Recurse -Force
Remove-Item (Join-Path $WebDir ".vercel") -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $WebDir -Filter "*.import" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$Coi = Join-Path $WebDir "coi-serviceworker.min.js"
if (-not (Test-Path $Coi)) {
	Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gzuidhof/coi-serviceworker/master/coi-serviceworker.min.js" -OutFile $Coi -UseBasicParsing
}

$htmlPath = Join-Path $WebDir "index.html"
$html = Get-Content $htmlPath -Raw
if ($html -notmatch "coi-serviceworker") {
	$html = $html -replace "<title>[^<]*</title>", "<title>Mentchik The Story — Demo</title>`n`t`t<script src=`"coi-serviceworker.min.js`"></script>"
	Set-Content -Path $htmlPath -Value $html -NoNewline
}

@'
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" },
        { "key": "Cross-Origin-Resource-Policy", "value": "same-origin" }
      ]
    }
  ]
}
'@ | Set-Content -Path (Join-Path $WebDir "vercel.json") -Encoding utf8

@'
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Resource-Policy: same-origin
'@ | Set-Content -Path (Join-Path $WebDir "_headers") -Encoding utf8

Write-Host "Web build synced to: $WebDir"
Write-Host "Push to GitHub to auto-deploy on Vercel (root directory = web)."
