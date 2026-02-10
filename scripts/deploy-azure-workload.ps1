# Installation script for Azure cluster dependencies workload with deployment apps of nginx, KEDA and Prometheus

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

    if ($env:USE_AKS_APP_ROUTING_ADDON -eq "true") {
        $INGRESS_HOST = Read-Host "Enter an ingress hostname (this is required for app routing addon+ingress rules to work. Add a DNS A record for hostname > ingress IP)"
        $env:INGRESS_HOST = $INGRESS_HOST
    }
    else {
        $env:INGRESS_HOST = ""
    }

    # Check if user is logged in to Azure
    $accountCheck = az account show 2>&1
    if ($LASTEXITCODE -ne 0) {
        az login
    }

    Write-Host "=== Beginning Azure env setup and Workload deployment (this will take several minutes) ===" -ForegroundColor Green
    Write-Host ""

    az aks get-credentials -n $env:CLUSTERNAME -g $env:RESOURCE_GROUP --overwrite-existing

    # Workload cluster dependencies
    Push-Location
    try {
        Set-Location ..\cluster-dependencies\general
        $result = & .\install-dependencies.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "=== General k8s cluster dependency deployment failed, exiting. ==="
            exit 1
        }
    }
    finally {
        Pop-Location
        Set-Location ..\scripts
    }

    # Azure cluster specific dependencies
    Push-Location
    try {
        Set-Location ..\cluster-dependencies\azure
        $result = & .\install-dependencies.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "=== AKS Cluster dependency deployment failed, exiting. ==="
            exit 1
        }
    }
    finally {
        Pop-Location
        Set-Location ..\scripts
    }

    # Add nginx ingress controller if required
    if (($env:PRIVATE_NETWORK -eq "false") -and ($env:USE_AKS_APP_ROUTING_ADDON -eq "false")) {
        $result = & .\_deploy-ingresscontroller.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "=== Ingress controller deploy failed, exiting. ==="
            exit 1
        }
    }

    # Upload demo app files to azure files
    $env:AZFILESSECRET = az storage account keys list --resource-group $env:RESOURCE_GROUP --account-name $env:AZFILESACNAME --query "[0].value" -o tsv

    $result = & .\_deploy-volumedata.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "=== Volumedata upload failed, exiting. ==="
        exit 1
    }

    # Deploy workload
    $result = & .\_deploy-workload.ps1 values-azure.yaml
    if ($LASTEXITCODE -ne 0) {
        Write-Error "=== Workload deployment failed, exiting. ==="
        exit 1
    }

    Write-Host "=== Installation complete! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Connect kubectl to your cluster with: az aks get-credentials -n $env:CLUSTERNAME -g $env:RESOURCE_GROUP --overwrite-existing"
    Write-Host ""

    if (![string]::IsNullOrWhiteSpace($env:GRAFANARESOURCENAME)) {
        az extension add --name amg
        $GRAFANA_URL = az grafana show --name $env:GRAFANARESOURCENAME --resource-group $env:RESOURCE_GROUP --query "properties.endpoint" -o tsv
        Write-Host "Grafana URL: $GRAFANA_URL"
        Write-Host ""
    }

    if (![string]::IsNullOrWhiteSpace($env:ACRRESOURCENAME)) {
        Write-Host "Azure container registry hostname: $($env:ACRRESOURCENAME).azurecr.io"
        Write-Host ""
    }

    Write-Host "To update deployment - run .\scripts\update-azure-workload.ps1"
    Write-Host ""
    Write-Host "To remove deployment - run .\scripts\undeploy-azure-workload.ps1"
} finally {
    Pop-Location
}
