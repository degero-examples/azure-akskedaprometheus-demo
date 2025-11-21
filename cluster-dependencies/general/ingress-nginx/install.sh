#!/bin/bash
# Installation script for basic NGINX Ingress Controller

set -e

# Configuration
NAMESPACE="ingress-nginx"
RELEASE_NAME="ingress-nginx-basic"
CHART_PATH="."  # Assumes you're in the chart directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}NGINX Ingress Controller Installer${NC}"
echo -e "${GREEN}===================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

# Check cluster connectivity
echo -e "${YELLOW}Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to cluster${NC}"
echo ""

# Add/update the ingress-nginx repository
echo -e "${YELLOW}Adding ingress-nginx Helm repository...${NC}"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
echo -e "${GREEN}✓ Repository updated${NC}"
echo ""

# Create namespace if it doesn't exist
echo -e "${YELLOW}Creating namespace: ${NAMESPACE}${NC}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace ready${NC}"
echo ""

# Update dependencies
echo -e "${YELLOW}Updating Helm dependencies...${NC}"
helm dependency update ${CHART_PATH}
echo -e "${GREEN}✓ Dependencies updated${NC}"
echo ""

# Install or upgrade the chart
echo -e "${YELLOW}Installing/Upgrading NGINX Ingress Controller...${NC}"
helm upgrade --install ${RELEASE_NAME} ${CHART_PATH} \
    --namespace ${NAMESPACE} \
    --values ${CHART_PATH}/values.yaml \
    --wait \
    --timeout 5m

echo -e "${GREEN}✓ Installation complete${NC}"
echo ""
