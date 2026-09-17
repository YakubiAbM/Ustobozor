# Upload fix_server_now.sh to VPS and run it
$ErrorActionPreference = "Stop"
$Server = "root@185.185.142.229"
$Script = Join-Path $PSScriptRoot "fix_server_now.sh"

Write-Host "==> Upload fix script"
scp -o ConnectTimeout=30 $Script "${Server}:/root/fix_server_now.sh"
if ($LASTEXITCODE -ne 0) {
    Write-Host "SSH/SCP failed. Use Timeweb console and run: bash /root/fix_server_now.sh"
    exit 1
}

Write-Host "==> Run fix on server"
$remoteCmd = "chmod +x /root/fix_server_now.sh; bash /root/fix_server_now.sh"
ssh -o ConnectTimeout=30 $Server $remoteCmd
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "==> Check from PC"
& curl.exe -sI --max-time 15 "https://ustomarket.tj/products?limit=1"
