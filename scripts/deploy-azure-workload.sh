#!/bin/bash
# Installation script for Azure cluster dependencies workload with deployment apps of nginx, KEDA and Prometheus

set -a
source .env.azure
set +a

export GREEN='\033[0;32m'
export NC='\033[0m'

read -p "Enter a value for GITHUBTOKEN (this is for demonstration use of a secret): " GITHUBTOKEN
export GITHUBTOKEN

if [ "$USE_AKS_APP_ROUTING_ADDON" = "true" ]; then
read -p "Enter a ingress hostname (this is required for app routing addon+ingress rules to work. Add a DNS A record for hostname > ingress IP): " INGRESS_HOST
export INGRESS_HOST
else
export INGRESS_HOST=
fi

echo -e "${GREEN}=== Beginning Azure env setup and Workload deployment (this will take several minutes) ===${NC}"
echo -e ""

az aks get-credentials -n $CLUSTERNAME -g $RESOURCE_GROUP --overwrite-existing

# Workload cluster dependencies
cd ../cluster-dependencies/general || exit 1
if ! bash ./install-dependencies.sh; then
    echo -e "${GREEN}=== General k8s cluster dependency deployment failed, exiting. ===${NC}" >&2
    exit 1
fi
cd ../../scripts || exit 1

# Azure cluster specific dependencies
cd ../cluster-dependencies/azure || exit 1
if ! bash ./install-dependencies.sh; then
    echo -e "${GREEN}=== AKS Cluster dependency deployment failed, exiting. ===${NC}" >&2
    exit 1
fi
cd ../../scripts || exit 1

# add nginx ingress controller if required
if [ "${PRIVATE_NETWORK:-}" = "false" ] && [ "${USE_AKS_APP_ROUTING_ADDON:-}" = "false" ]; then
if ! bash ./_deploy-ingresscontroller.sh; then
    echo -e "${GREEN}=== Igress controller deploy failed, exiting. ===${NC}" >&2
    exit 1
fi
fi

# # Upload demo app files to azure files 
export AZFILESSECRET=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $AZFILESACNAME --query "[0].value" -o tsv)

if ! bash ./_deploy-volumedata.sh; then
    echo -e "${GREEN}=== Volumedata upload failed, exiting. ===${NC}" >&2
    exit 1
fi

# Deploy workload
if ! bash ./_deploy-workload.sh values-azure.yaml; then
    echo -e "${GREEN}=== Workload deployment failed, exiting. ===${NC}" >&2
    exit 1
fi

echo -e "${GREEN}=== Installiation complete! ===${NC}"
echo -e ""
echo -e "Connect kubectl to your cluster with az aks get-credentials -n $CLUSTERNAME -g $RESOURCE_GROUP --overwrite-existing"
echo -e ""
if [ "${GRAFANARESOURCENAME:-}" != "" ]; then
  az extension add --name amg
  GRAFANA_URL=$(az grafana show --name $GRAFANARESOURCENAME --resource-group $RESOURCE_GROUP --query "properties.endpoint" -o tsv)
  echo -e "Grafana URL: $GRAFANA_URL"
  echo -e ""
fi
if [ "${ACRRESOURCENAME:-}" != "" ]; then
  echo -e "Azure container registry hostname: $ACRRESOURCENAME.azurecr.io"
  echo -e ""
fi
echo -e "To remove deployment - run undeploy-azure-workload.sh ==="
