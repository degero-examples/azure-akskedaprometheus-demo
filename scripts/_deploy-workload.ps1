# Deploy app workload with Azure specific settings

Write-Host "=== Workload deployment starting. ===" -ForegroundColor Green

if ($env:PRIVATE_NETWORK -eq "true") {
    $values_file = "values-azure-lb.yaml"
}
else {
    $values_file = "values-azure-ingress.yaml"
}

# Set ingressclass if approuting addon turned on in AKS
if ($env:USE_AKS_APP_ROUTING_ADDON -eq "true") {
    $ingress_class = "webapprouting.kubernetes.azure.com"
}
else {
    $ingress_class = "ingress-nginx-basic"
}

helm upgrade --install $env:APPNAME ..\workload\chart --namespace default --create-namespace `
    -f ..\workload\values-base.yaml `
    -f ..\workload\$values_file `
    --set-string githubTokenSecret.token=$env:GITHUBTOKEN `
    --set azureFilesSecret.accountKey=$env:AZFILESSECRET `
    --set azureFilesSecret.accountName=$env:AZFILESACNAME `
    --set workloadIdentity.clientId=$env:KEDAUSERASSIGNEDIDENTITYCLIENTID `
    --set kedaPrometheusAccess.serverAddress=$env:PROMETHEUSQUERYENDPOINT `
    --set privateNetwork.enabled=$env:PRIVATE_NETWORK `
    --set ingress.ingressClassName=$ingress_class `
    --set ingress.aksManaged=$env:USE_AKS_APP_ROUTING_ADDON `
    --set ingress.host=$env:INGRESS_HOST `
    --set volumes[0].shareName="$env:AZFILESSHARE_APPONE" `
    --set volumes[1].shareName="$env:AZFILESSHARE_APPTWO"

Write-Host "=== Workload deployment completed successfully! ===" -ForegroundColor Green
