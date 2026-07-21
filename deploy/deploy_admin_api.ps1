# Deploy Admin Mobile API to prod VPS
$ErrorActionPreference = "Stop"
$Server = "root@185.185.142.229"
$RemoteDir = "/root/backendGreen"
$LocalBagk = Join-Path (Split-Path $PSScriptRoot -Parent) "UstoMarketBagk"

function Invoke-Remote([string]$Cmd) {
  ssh -o ConnectTimeout=30 -o BatchMode=yes $Server $Cmd
  if ($LASTEXITCODE -ne 0) { throw "SSH failed: $Cmd" }
}

Write-Host "==> Upload admin_mobile_api.py + main.py"
scp -o ConnectTimeout=30 -o BatchMode=yes `
  (Join-Path $LocalBagk "admin_mobile_api.py") `
  (Join-Path $LocalBagk "main.py") `
  "${Server}:${RemoteDir}/"
if ($LASTEXITCODE -ne 0) { throw "SCP failed (SSH timeout?). Connect manually: ssh $Server" }

Write-Host "==> Restart ustobozor"
Invoke-Remote "systemctl restart ustobozor && sleep 2 && systemctl is-active ustobozor"

Write-Host "==> Verify on server"
Invoke-Remote "curl -sS -o /dev/null -w 'dashboard:%{http_code}\n' http://127.0.0.1:8000/admin/api/dashboard"

Write-Host "Done."
