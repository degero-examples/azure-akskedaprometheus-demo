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

    # TODO move these to uninstall-dependencies.ps1
    az aks get-credentials -n $env:CLUSTERNAME -g $env:RESOURCE_GROUP --overwrite-existing

    Write-Host "=== Uninstalling Prometheus CRDs via HELM (required by KEDA) ===" -ForegroundColor Green
    helm uninstall prometheus-operator-crds -n kube-system

    Write-Host "=== Uninstalling KEDA via Helm with prometheus scrape annotations ===" -ForegroundColor Green
    helm uninstall keda --namespace keda
    kubectl delete ns keda

    Write-Host "=== Removing keda managed identity and AMA metrics scrape configmap ===" -ForegroundColor Green
    kubectl delete configmap ama-metrics-settings-configmap -n kube-system

    if (($env:PRIVATE_NETWORK -eq "false") -and ($env:USE_AKS_APP_ROUTING_ADDON -eq "false")) {
        Write-Host "=== Uninstalling basic ingress-nginx implementation ===" -ForegroundColor Green
        
        Push-Location
        try {
            Set-Location ..\cluster-dependencies\general\ingress-nginx
            $result = & .\uninstall.ps1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "=== Ingress uninstallation failed, exiting. ==="
                exit 1
            }
            Write-Host "=== Ingress uninstallation completed successfully. ===" -ForegroundColor Green
        }
        finally {
            Pop-Location
            Set-Location ..\scripts
        }
    }

    Write-Host "=== Uninstalling workload ===" -ForegroundColor Green
    helm uninstall $env:APPNAME

    Write-Host "=== Uninstallation complete! ===" -ForegroundColor Green
} finally {
    Pop-Location
}