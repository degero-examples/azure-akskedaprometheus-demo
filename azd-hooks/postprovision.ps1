# Post-provision hook to setup auth and deploy workload after infrastructure is set up

Set-Location scripts

Remove-Item -Force .env.azure -ErrorAction SilentlyContinue

azd env get-values | Out-File .env.azure

# This is written for manual script runs in /scripts to access (eg undeploy)
Write-Host "=== Env vars updated to /scripts/.env.azure" -ForegroundColor Green

# need helm and kubectl for workload deploy
powershell.exe -ExecutionPolicy Bypass -File .\install-local-dependencies.ps1

if ($LASTEXITCODE -ne 0) {
    Write-Host "=== Local dependency install failed, exiting. ===" -ForegroundColor Green
    exit 1
}


powershell.exe -ExecutionPolicy Bypass -File .\deploy-azure-workload.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "=== Workload deployment failed, exiting. ===" -ForegroundColor Green
    exit 1
}

Set-Location ..