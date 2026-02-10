# Pre-provision hook to setup dependencies

# Check if user is logged in to Azure
az account show 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    az login
}

Write-Host "=== Checking provider Microsoft.ContainerService is registered..."  -ForegroundColor Green

$registrationState = az provider show --namespace "Microsoft.ContainerService" --query "registrationState" -o tsv
if ($registrationState -ne "Registered") {
    Write-Host "=== Registering provider Microsoft.ContainerService..." -ForegroundColor Green
    az provider register --namespace "Microsoft.ContainerService"
    while ((az provider show --namespace "Microsoft.ContainerService" --query "registrationState" -o tsv) -ne "Registered") {
        Write-Host "=== Waiting for Microsoft.ContainerService provider registration..."
        Start-Sleep -Seconds 3
    }
} else {
    Write-Host "=== Provider Microsoft.ContainerService is already registered." -ForegroundColor Green
}

# add azure cli extensions
az extension add --upgrade --name aks-preview