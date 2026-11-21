# Export Mentchik The Story for browser, sync to web/ (Vercel root via GitHub).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Godot = Join-Path $Root "godot_bin\Godot_v4.2.2-stable_win64_console.exe"
$BuildDir = Join-Path $Root "build\web"
$WebDir = Join-Path $Root "web"
$OutHtml = Join-Path $BuildDir "index.html"

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
# Godot prints warnings on stderr; don't treat them as terminating errors.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $Godot --headless --path $Root --export-release "Web" $OutHtml 2>&1 | Out-Host
$exportCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($exportCode -ne 0) { throw "Godot web export failed ($exportCode)" }
if (-not (Test-Path $OutHtml)) { throw "Web export missing output: $OutHtml" }

if (Test-Path $WebDir) { Remove-Item $WebDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $WebDir | Out-Null
Copy-Item (Join-Path $BuildDir "*") -Destination $WebDir -Recurse -Force
Remove-Item (Join-Path $WebDir ".vercel") -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $WebDir -Filter "*.import" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$Coi = Join-Path $WebDir "coi-serviceworker.min.js"
if (-not (Test-Path $Coi)) {
	Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gzuidhof/coi-serviceworker/master/coi-serviceworker.min.js" -OutFile $Coi -UseBasicParsing
}

# Favicon for browsers that ignore PNG engine icon / aggressive cache
Copy-Item (Join-Path $Root "img\icon.ico") (Join-Path $WebDir "favicon.ico") -Force
Copy-Item (Join-Path $Root "img\favicon.png") (Join-Path $WebDir "favicon.png") -Force -ErrorAction SilentlyContinue

$htmlPath = Join-Path $WebDir "index.html"
$html = Get-Content $htmlPath -Raw
$html = $html -replace "<title>[^<]*</title>", "<title>Mentchik The Story</title>"
if ($html -notmatch "coi-serviceworker") {
	$html = $html -replace "<title>Mentchik The Story</title>", "<title>Mentchik The Story</title>`n`t`t<script src=`"coi-serviceworker.min.js`"></script>"
}
# Force Mentchik icons ahead of any leftover Godot defaults
$iconBlock = @"
<link rel="icon" href="favicon.ico?v=3" sizes="any" />
		<link rel="icon" type="image/png" href="index.icon.png?v=3" />
		<link rel="apple-touch-icon" href="index.apple-touch-icon.png?v=3" />
"@
if ($html -notmatch 'favicon\.ico\?v=') {
	$html = $html -replace "<head>", "<head>`n`t`t$iconBlock"
}
Set-Content -Path $htmlPath -Value $html -NoNewline

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
    },
    {
      "source": "/index.html",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache" }
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
