# Apply nginx cache config for ustobozor.tj
$ErrorActionPreference = "Stop"
$Server = "root@185.185.142.229"
$RemoteConfig = "/etc/nginx/sites-available/ustobozor"
$LocalConfig = Join-Path $PSScriptRoot "nginx-ustobozor-production.conf"
$Backup = "/etc/nginx/sites-available/ustobozor.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "==> Backup current nginx config to $Backup"
ssh -o ConnectTimeout=30 -o BatchMode=yes $Server "cp $RemoteConfig $Backup && echo Backup OK: $Backup"

Write-Host "==> Upload new config"
scp -o ConnectTimeout=30 -o BatchMode=yes $LocalConfig "${Server}:${RemoteConfig}"
if ($LASTEXITCODE -ne 0) { throw "SCP failed" }

Write-Host "==> nginx -t"
ssh -o ConnectTimeout=30 -o BatchMode=yes $Server "nginx -t"
if ($LASTEXITCODE -ne 0) {
    Write-Host "==> RESTORE from latest backup"
    ssh -o ConnectTimeout=30 -o BatchMode=yes $Server "cp $Backup $RemoteConfig && nginx -t"
    throw "nginx -t failed; config restored from backup"
}

Write-Host "==> reload nginx"
ssh -o ConnectTimeout=30 -o BatchMode=yes $Server "systemctl reload nginx && systemctl is-active nginx"

Write-Host "==> Verify Cache-Control headers"
ssh -o ConnectTimeout=30 -o BatchMode=yes $Server @"
curl -sSI http://127.0.0.1/app.css?v=29 -H 'Host: ustobozor.tj' | grep -iE 'HTTP/|cache-control|expires'
curl -sSI http://127.0.0.1/static/images/ -H 'Host: ustobozor.tj' | head -3
"@

Write-Host "Done."
