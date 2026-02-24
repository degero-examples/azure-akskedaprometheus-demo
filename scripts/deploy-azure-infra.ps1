# Deploy Azure infrastructure via bicep and write outputs to ../scripts/.env.azure to deploy workload to cluster

$ErrorActionPreference = "Stop"

# Prompt user for location and resource group name
do {
    $LOCATION = Read-Host "Resource group location (e.g. eastus)"
    if ([string]::IsNullOrWhiteSpace($LOCATION)) {
        Write-Host "Resource group location is required."
    }
} while ([string]::IsNullOrWhiteSpace($LOCATION))

do {
    $RESOURCE_GROUP = Read-Host "Resource group name"
    if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
        Write-Host "Resource group name is required."
    }
} while ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP))


# Change to script directory
Push-Location $PSScriptRoot
try {

    Write-Host "Creating resource group '$RESOURCE_GROUP' in location '$LOCATION'..."
    az group create -l $LOCATION -n $RESOURCE_GROUP

    # Deploy bicep template
    Write-Host "Deploying bicep template..."
    az deployment group create -g $RESOURCE_GROUP --template-file ..\infra\main.bicep --parameters ..\infra\default.bicepparam

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Deployment failed."
        exit 1
    }

    # Get all output names
    $output_names = az deployment group show `
        --resource-group $RESOURCE_GROUP `
        --name main `
        --query 'properties.outputs | keys(@)' `
        -o tsv

# Create the env file header
@'
# Auto-generated from Azure bicep deployment outputs

'@ | Out-File -FilePath .\.env.azure -Encoding utf8

    # Loop through each output and get its value
    foreach ($output_name in $output_names) {
        $output_value = az deployment group show `
            --resource-group $RESOURCE_GROUP `
            --name main `
            --query "properties.outputs.$output_name.value" `
            -o tsv
        
        # Write to file
        $KEY = $output_name.ToUpper()
        "`$$KEY=`"$output_value`"" | Out-File -FilePath ..\scripts\.env.azure -Append -Encoding utf8
    }

    Write-Host "All environment variables written to \scripts\.env.azure"
    Write-Host ""
    Write-Host "Run .\scripts\deploy-azure-workload.ps1 to deploy the dependencies and workload to AKS"

} finally {
    Pop-Location
}