#!/bin/bash
# Installation script for local KIND cluster with KEDA and Prometheus

# Colors for output
export GREEN='\033[0;32m'
export NC='\033[0m' # No Color

read -p "Enter a value for GITHUBTOKEN (this is for demonstration use of a secret): " GITHUBTOKEN
export GITHUBTOKEN
read -p "Use private network (true/false): " PRIVATE_NETWORK
export PRIVATE_NETWORK
echo -e "${GREEN}=== Beginning Cluster creation and Workload Deployment (this will take several minutes) ===${NC}"
echo -e ""
echo -e "${GREEN}=== Creating KIND cluster ===${NC}"
kind create cluster --config ./kind/kind-config.yaml
echo -e "${GREEN}=== Waiting for cluster to start up ===${NC}"
kubectl wait --for=condition=Ready node kind-control-plane --timeout=180s

cd ../cluster-dependencies/general || exit 1
if ! bash ./install-dependencies.sh; then
    echo -e "${GREEN}=== General k8s cluster dependency deployment failed, exiting. ===${NC}" >&2
    exit 1
fi
cd ../../localdev || exit 1

echo -e ""
echo -e "${GREEN}=== Adding KIND cluster specific dependencies ===${NC}"
echo -e ""
echo -e "${GREEN}=== Adding kube metrics server Helm repo and updating ===${NC}"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

echo -e "${GREEN}=== Installing metrics-server via HELM ===${NC}" 
helm upgrade --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system --version 3.13.0
echo -e "${GREEN}=== Installing kube-state-metrics via Helm ===${NC}"
helm install --wait kube-state-metrics prometheus-community/kube-state-metrics -n kube-system --version 6.4.1
echo -e "${GREEN}=== Applying promethus and annotation based scraping rules manfest ===${NC}"
kubectl apply -f ./kind/prometheus.yaml
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s

if [ "${PRIVATE_NETWORK:-}" = "false" ]; then
    echo -e "${GREEN}=== Installing nginx ingress controller designed for KIND ===${NC}"
    kubectl apply -f ./kind/ingress-nginx.yaml
fi

if [ "${PRIVATE_NETWORK:-}" = "true" ]; then
    echo -e "${GREEN}=== Pulling KIND cloud-provider-kind load balancer for KIND cluster ===${NC}"
    docker pull registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.7.0
    docker tag registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.7.0 cloud-controller-manager:v0.7.0
fi

echo -e "${GREEN}=== Installing workload ===${NC}"

if [ "$PRIVATE_NETWORK" = "true" ]; then
    values_file="values-localdev-lb.yaml"
else
    values_file="values-localdev-ingress.yaml"
fi

helm upgrade --install kedascalerapp ../workload/chart --namespace default --create-namespace -f ../workload/values-base.yaml -f ../workload/$values_file --set githubTokenSecret.token=$GITHUBTOKEN --set privateNetwork.enabled=$PRIVATE_NETWORK

echo -e "${GREEN}=== Installiation complete! ===${NC}"
echo -e ""
echo -e "${GREEN}=== To remove cluster/deployment - run delete-localdev.sh ===${NC}"
