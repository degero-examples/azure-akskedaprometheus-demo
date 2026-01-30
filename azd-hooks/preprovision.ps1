# Pre-provision hook to setup dependencies

Write-Host "Checking provider Microsoft.ContainerService is registered..."

$registrationState = az provider show --namespace "Microsoft.ContainerService" --query "registrationState" -o tsv
if ($registrationState -ne "Registered") {
    Write-Host "Registering provider Microsoft.ContainerService..."
    az provider register --namespace "Microsoft.ContainerService"
    while ((az provider show --namespace "Microsoft.ContainerService" --query "registrationState" -o tsv) -ne "Registered") {
        Write-Host "Waiting for Microsoft.ContainerService provider registration..."
        Start-Sleep -Seconds 3
    }
} else {
    Write-Host "Provider Microsoft.ContainerService is already registered."
}

# add azure cli extensions
az extension add --upgrade --name aks-preview