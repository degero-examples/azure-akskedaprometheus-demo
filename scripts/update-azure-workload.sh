#!/bin/bash
# Installation script for Azure workload with deployment apps of nginx, KEDA and Prometheus

# Colors for output
export GREEN='\033[0;32m'
export NC='\033[0m' # No Colorsource

set -a
source .env.azure
set +a


read -p "Enter a value for GITHUBTOKEN (this is for demonstration use of a secret): " GITHUBTOKEN
export GITHUBTOKEN

export AZFILESSECRET=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $AZFILESACNAME --query "[0].value" -o tsv)

# Deploy workload
if ! bash ./_deploy-workload.sh values-azure.yaml; then
    echo -e "${GREEN}=== Workload updated failed, exiting. ===${NC}" >&2
    exit 1
fi