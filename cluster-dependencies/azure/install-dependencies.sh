#!/bin/bash
# Install AKS cluster dependencies (Azure Monitor Metrics Configmap for Prometheus scraping)

echo -e "${GREEN}=== AKS Cluster dependency deployment starting. ===${NC}"
 
echo -e "${GREEN}=== Updating KEDA via HELM for Azure pod identity to access Azure Monitor Prometheus ===${NC}"

echo -e "${GREEN}=== Adding AMA metrics prometheus scrape configmap ===${NC}"

kubectl apply -f kube-system/ama-metrics-settings-configmap.yaml

echo -e "${GREEN}=== AKS Cluster dependencies deployment finished. ===${NC}"