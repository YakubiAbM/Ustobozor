# Deploy PWA web (SEO) to prod VPS
$ErrorActionPreference = "Stop"
$Server = "root@185.185.142.229"
$RemoteDir = "/root/backendGreen/web"
$LocalWeb = Join-Path (Split-Path $PSScriptRoot -Parent) "UstoMarketBagk\web"

$files = @(
  "index.html",
  "app.js",
  "app.css",
  "sw.js",
  "manifest.json",
  "robots.txt",
  "icons.js",
  "qrcode.min.js",
  "privacy.html",
  "google27333c26b5d02584.html",
  "favicon-32.png",
  "icon-192.png",
  "icon-512.png",
  "apple-touch-icon.png"
)

Write-Host "==> Upload fonts"
$LocalFonts = Join-Path (Split-Path $PSScriptRoot -Parent) "UstoMarketBagk\static\fonts"
$RemoteFonts = "/root/backendGreen/static/fonts"
if (-not (Test-Path $LocalFonts)) { throw "Missing $LocalFonts" }
ssh -o ConnectTimeout=30 -o BatchMode=yes $Server "mkdir -p $RemoteFonts"
Get-ChildItem -Path $LocalFonts -Filter "*.woff2" | ForEach-Object {
  scp -o ConnectTimeout=30 -o BatchMode=yes $_.FullName "${Server}:${RemoteFonts}/"
  if ($LASTEXITCODE -ne 0) { throw "SCP failed: $($_.Name)" }
}
Write-Host "  OK fonts (*.woff2)"

Write-Host "==> Upload favicon"
$LocalFavicon = Join-Path (Split-Path $PSScriptRoot -Parent) "UstoMarketBagk\static\images\favicon.png"
$RemoteImages = "/root/backendGreen/static/images"
if (-not (Test-Path $LocalFavicon)) { throw "Missing $LocalFavicon" }
ssh -o ConnectTimeout=30 -o BatchMode=yes $Server "mkdir -p $RemoteImages"
scp -o ConnectTimeout=30 -o BatchMode=yes $LocalFavicon "${Server}:${RemoteImages}/favicon.png"
if ($LASTEXITCODE -ne 0) { throw "SCP failed: favicon" }
Write-Host "  OK favicon.png"

Write-Host "==> Upload web SEO files"
foreach ($f in $files) {
  $local = Join-Path $LocalWeb $f
  if (-not (Test-Path $local)) { throw "Missing $local" }
  scp -o ConnectTimeout=30 -o BatchMode=yes $local "${Server}:${RemoteDir}/"
  if ($LASTEXITCODE -ne 0) { throw "SCP failed: $f" }
  Write-Host "  OK $f"
}

Write-Host "==> Verify on server"
ssh -o ConnectTimeout=30 -o BatchMode=yes $Server 'curl -sS http://127.0.0.1:8000/ | grep -o "<title>[^<]*</title>" | sed -n "1p"; curl -sS -o /dev/null -w "home:%{http_code}\n" http://127.0.0.1:8000/'

Write-Host "Done."
