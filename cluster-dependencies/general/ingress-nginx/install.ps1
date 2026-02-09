# Installation script for basic NGINX Ingress Controller

$ErrorActionPreference = "Stop"

# Configuration
$NAMESPACE = "ingress-nginx"
$RELEASE_NAME = "ingress-nginx-basic"
$CHART_PATH = "."  # Assumes you're in the chart directory

Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "NGINX Ingress Controller Installer" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host ""

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl is not installed" -ForegroundColor Red
    exit 1
}

# Check if helm is available
if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Host "Error: helm is not installed" -ForegroundColor Red
    exit 1
}

# Check cluster connectivity
Write-Host "Checking cluster connectivity..." -ForegroundColor Yellow
try {
    kubectl cluster-info | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "Error: Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Connected to cluster" -ForegroundColor Green
Write-Host ""

# Add/update the ingress-nginx repository
Write-Host "Adding ingress-nginx Helm repository..." -ForegroundColor Yellow
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
Write-Host "✓ Repository updated" -ForegroundColor Green
Write-Host ""

# Create namespace if it doesn't exist
Write-Host "Creating namespace: $NAMESPACE" -ForegroundColor Yellow
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
Write-Host "✓ Namespace ready" -ForegroundColor Green
Write-Host ""

# Update dependencies
Write-Host "Updating Helm dependencies..." -ForegroundColor Yellow
helm dependency update $CHART_PATH
Write-Host "✓ Dependencies updated" -ForegroundColor Green
Write-Host ""

# Install or upgrade the chart
Write-Host "Installing/Upgrading NGINX Ingress Controller..." -ForegroundColor Yellow
helm upgrade --install $RELEASE_NAME $CHART_PATH `
    --namespace $NAMESPACE `
    --values "$CHART_PATH/values.yaml" `
    --wait `
    --timeout 5m

Write-Host "✓ Installation complete" -ForegroundColor Green
Write-Host ""