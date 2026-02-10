# Installation script for Azure workload with deployment apps of nginx, KEDA and Prometheus

# Change to script directory
Push-Location $PSScriptRoot
try {

    # Source environment variables from .env.azure
    if (Test-Path .\.env.azure) {
        Get-Content .\.env.azure | ForEach-Object {
            if ($_ -match '^\$?([^=]+)="?([^"]*)"?$') {
                $name = $matches[1]
                $value = $matches[2]
                Set-Item -Path "env:$name" -Value $value
            }
        }
    }
    else {
        Write-Error ".env.azure file not found"
        exit 1
    }

    $GITHUBTOKEN = Read-Host "Enter a value for GITHUBTOKEN (this is for demonstration use of a secret)"
    $env:GITHUBTOKEN = $GITHUBTOKEN

    $env:AZFILESSECRET = az storage account keys list --resource-group $env:RESOURCE_GROUP --account-name $env:AZFILESACNAME --query "[0].value" -o tsv

    az aks get-credentials -n $env:CLUSTERNAME -g $env:RESOURCE_GROUP --overwrite-existing

    # Deploy workload
    $result = & .\_deploy-workload.ps1 values-azure.yaml
    if ($LASTEXITCODE -ne 0) {
        Write-Error "=== Workload update failed, exiting. ==="
        exit 1
    }

    Write-Host "=== Workload update completed! ===" -ForegroundColor Green
} finally {
    Pop-Location
}