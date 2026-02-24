# Install AKS cluster dependencies (Azure Monitor Metrics Configmap for Prometheus scraping)

Write-Host "=== AKS Cluster dependency deployment starting. ===" -ForegroundColor Green

Write-Host "=== Updating KEDA via HELM for Azure pod identity to access Azure Monitor Prometheus ===" -ForegroundColor Green

Write-Host "=== Adding AMA metrics prometheus scrape configmap ===" -ForegroundColor Green

kubectl apply -f kube-system/ama-metrics-settings-configmap.yaml
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "=== AKS Cluster dependencies deployment finished. ===" -ForegroundColor Green