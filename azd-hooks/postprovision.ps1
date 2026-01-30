# Post-provision hook to setup auth and deploy workload after infrastructure is set up

# Colors for output
$GREEN = [ConsoleColor]::Green
$NC = [ConsoleColor]::White

Set-Location scripts
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""

Remove-Item -Force .env.azure -ErrorAction SilentlyContinue

azd env get-values | Out-File .env.azure

# This is written for manual script runs in /scripts to access (eg undeploy)
Write-Host "=== Env vars updated to /scripts/.env.azure" -ForegroundColor Green

& bash.exe .\deploy-azure-workload.sh
if ($LASTEXITCODE -ne 0) {
    Write-Host "=== Workload deployment failed, exiting. ===" -ForegroundColor Green
    exit 1
}

Set-Location ..
if ($LASTEXITCODE -ne 0) { exit 1 }