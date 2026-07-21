# Download self-hosted Inter & Montserrat woff2 (Fontsource / OFL)
$ErrorActionPreference = "Stop"
$base = Join-Path (Split-Path $PSScriptRoot -Parent) "UstoMarketBagk\static\fonts"
New-Item -ItemType Directory -Force -Path $base | Out-Null
$cdn = "https://cdn.jsdelivr.net/npm/@fontsource"
$map = @{
  "inter-400-cyr.woff2" = "$cdn/inter@5.2.5/files/inter-cyrillic-400-normal.woff2"
  "inter-500-cyr.woff2" = "$cdn/inter@5.2.5/files/inter-cyrillic-500-normal.woff2"
  "inter-600-cyr.woff2" = "$cdn/inter@5.2.5/files/inter-cyrillic-600-normal.woff2"
  "inter-700-cyr.woff2" = "$cdn/inter@5.2.5/files/inter-cyrillic-700-normal.woff2"
  "inter-400-latin.woff2" = "$cdn/inter@5.2.5/files/inter-latin-400-normal.woff2"
  "inter-500-latin.woff2" = "$cdn/inter@5.2.5/files/inter-latin-500-normal.woff2"
  "inter-600-latin.woff2" = "$cdn/inter@5.2.5/files/inter-latin-600-normal.woff2"
  "inter-700-latin.woff2" = "$cdn/inter@5.2.5/files/inter-latin-700-normal.woff2"
  "montserrat-600-cyr.woff2" = "$cdn/montserrat@5.2.5/files/montserrat-cyrillic-600-normal.woff2"
  "montserrat-700-cyr.woff2" = "$cdn/montserrat@5.2.5/files/montserrat-cyrillic-700-normal.woff2"
  "montserrat-600-latin.woff2" = "$cdn/montserrat@5.2.5/files/montserrat-latin-600-normal.woff2"
  "montserrat-700-latin.woff2" = "$cdn/montserrat@5.2.5/files/montserrat-latin-700-normal.woff2"
}
foreach ($entry in $map.GetEnumerator()) {
  $out = Join-Path $base $entry.Key
  Write-Host "Downloading $($entry.Key)..."
  Invoke-WebRequest -Uri $entry.Value -OutFile $out -UseBasicParsing
}
Write-Host "Done. Fonts in $base"
