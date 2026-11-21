# Export Mentchik / Les Eclats de Chartres for browser (HTML5) and optionally redeploy.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Godot = Join-Path $Root "godot_bin\Godot_v4.2.2-stable_win64_console.exe"
$OutDir = Join-Path $Root "build\web"
$OutHtml = Join-Path $OutDir "index.html"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

& $Godot --headless --path $Root --export-release "Web" $OutHtml
if ($LASTEXITCODE -ne 0) { throw "Godot web export failed ($LASTEXITCODE)" }

# COOP/COEP shim for hosts that don't set isolation headers
$Coi = Join-Path $OutDir "coi-serviceworker.min.js"
if (-not (Test-Path $Coi)) {
	Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gzuidhof/coi-serviceworker/master/coi-serviceworker.min.js" -OutFile $Coi -UseBasicParsing
}

$html = Get-Content $OutHtml -Raw
if ($html -notmatch "coi-serviceworker") {
	$html = $html -replace "<title>Les Eclats de Chartres</title>", "<title>Mentchik The Story — Demo</title>`n`t`t<script src=`"coi-serviceworker.min.js`"></script>"
	Set-Content -Path $OutHtml -Value $html -NoNewline
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
'@ | Set-Content -Path (Join-Path $OutDir "vercel.json") -Encoding utf8

@'
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Resource-Policy: same-origin
'@ | Set-Content -Path (Join-Path $OutDir "_headers") -Encoding utf8

Write-Host "Web build ready: $OutDir"
Write-Host 'Redeploy: npx --yes vercel deploy build\web --yes --prod --name mentchik-the-story'
