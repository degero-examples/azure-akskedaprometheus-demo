# Install general k8s cluster dependencies for the workload (KEDA, Prometheus Operator CRDs)

Write-Host "=== General k8s Cluster dependency deployment starting. ===" -ForegroundColor Green
Write-Host ""

Write-Host "=== Adding HELM repos for Prometheus and KEDA and updating ===" -ForegroundColor Green
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
if ($LASTEXITCODE -ne 0) { exit 1 }

helm repo add kedacore https://kedacore.github.io/charts
if ($LASTEXITCODE -ne 0) { exit 1 }

helm repo update
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "=== Installing Prometheus CRDs via HELM (required by KEDA) ===" -ForegroundColor Green
Write-Host ""

helm install --wait prometheus-operator-crds prometheus-community/prometheus-operator-crds -n kube-system --version 24.0.2
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "=== Installing KEDA via Helm with promethus scrape annotations ===" -ForegroundColor Green
Write-Host ""

helm install --wait --timeout 8m keda kedacore/keda --namespace keda --create-namespace --set serviceAccount.create=false --version 2.18.1 --set serviceAccount.name=keda-operator --set podIdentity.azureWorkload.enabled=true --set podIdentity.azureWorkload.clientId=$env:KEDAUSERASSIGNEDIDENTITYCLIENTID --set podIdentity.azureWorkload.tenantId=$env:AZURE_TENANT_ID --set meta.helm.sh/release-namespace=helm --set prometheus.operator.enabled=true --set prometheus.metricServer.enabled=true --set prometheus.operator.serviceMonitor.enabled=true --set prometheus.metricServer.serviceMonitor.enabled=true
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "=== Patching KEDA prometheus scrape annotations ===" -ForegroundColor Green

## hack to solve unimaginiable pwsh escaping issues driving me batshit crazy
@'
{"spec": {"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/path":"/metrics","prometheus.io/port":"8080"}}}}}
'@ | Out-File -FilePath "keda-patch.json" -Encoding utf8 -NoNewline

kubectl patch deployment keda-operator -n keda --patch-file "keda-patch.json"
if ($LASTEXITCODE -ne 0) {
    Remove-Item "keda-patch.json"
    exit 1 
}
Remove-Item "keda-patch.json"

Write-Host ""
Write-Host "=== General k8s Cluster dependency deployment finished. ===" -ForegroundColor Green
Write-Host ""