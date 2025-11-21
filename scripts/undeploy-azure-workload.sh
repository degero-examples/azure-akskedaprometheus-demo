#!/bin/bash
# Installation script for Azure workload with deployment apps of nginx, KEDA and Prometheus

# Colors for output
export GREEN='\033[0;32m'
export NC='\033[0m' # No Colorsource

set -a
source .env.azure
set +a

# TODO move these to uninstall-dependencies.sh
az aks get-credentials -n $CLUSTERNAME -g $RESOURCE_GROUP --overwrite-existing
echo -e "${GREEN}=== Uninstalling Prometheus CRDs via HELM (required by KEDA) ===${NC}"
helm uninstall prometheus-operator-crds -n kube-system
echo -e "${GREEN}=== Uninstalling KEDA via Helm with promethus scrape annotations ===${NC}"
helm uninstall keda --namespace keda
kubectl delete ns keda  
echo -e "${GREEN}=== Removing keda managed identity and AMA metrics scrape configmap ===${NC}"
kubectl delete configmap ama-metrics-settings-configmap -n kube-system

if [ "${PRIVATE_NETWORK:-}" = "false" ] && [ "${USE_AKS_APP_ROUTING_ADDON:-}" = "false" ]; then
    echo -e "${GREEN}=== Uninstalling basic ingress-nginx implementation ===${NC}"
    cd ../cluster-dependencies/general/ingress-nginx
    if ! bash ./uninstall.sh; then
        echo -e "${GREEN}=== Ingress uninstallation failed, exiting." >&2
        exit 1
    fi
    echo -e "${GREEN}=== Ingress uninstallation completed successfully. ===${NC}"
    cd ../../../scripts
fi

echo -e "${GREEN}=== Uninstalling workload ===${NC}"

helm uninstall $APPNAME

echo -e "${GREEN}=== Uninstalliation complete! ===${NC}"