#!/bin/bash
# Pre-provision hook to setup dependencies

echo "Checking provider Microsoft.ContainerService is registered..."

if [ "$(az provider show --namespace "Microsoft.CognitiveServices" --query "registrationState" -o tsv)" != "Registered" ]; then
    echo "Registering provider Microsoft.ContainerService..."
    az provider register --namespace "Microsoft.ContainerService"
    while [ "$(az provider show --namespace "Microsoft.ContainerService" --query "registrationState" -o tsv)" != "Registered" ]; do
    echo "Waiting for Microsoft.ContainerService provider registration..."
    sleep 3
    done
else
    echo "Provider Microsoft.ContainerService is already registered."
fi

# add azure cli extensions
az extension add --upgrade --name aks-preview
