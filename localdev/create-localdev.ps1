# Installation script for local KIND cluster with KEDA and Prometheus

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "Green"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Change to script directory
Push-Location $PSScriptRoot
try {

    # Prompt for inputs
    $GITHUBTOKEN = Read-Host "Enter a value for GITHUBTOKEN (this is for demonstration use of a secret)"
    $PRIVATE_NETWORK = Read-Host "Use private network (true/false)"

    Write-ColorOutput "=== Beginning Cluster creation and Workload Deployment (this will take several minutes) ==="
    Write-Host ""

    Write-ColorOutput "=== Creating KIND cluster ==="
    kind create cluster --config .\kind\kind-config.yaml
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-ColorOutput "=== Switching your kubectl context to 'kind-kind' ==="
    kubectl config use-context kind-kind
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-ColorOutput "=== Waiting for cluster to start up ==="
    kubectl wait --for=condition=Ready node kind-control-plane --timeout=180s
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-ColorOutput "=== Running general k8s cluster dependency deployment ==="
    # Workload cluster dependencies
    Push-Location
    try {
        Set-Location ..\cluster-dependencies\general
        $result = & .\install-dependencies.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "=== General k8s cluster dependency deployment failed, exiting. ==="
            exit 1
        }
    }
    finally {
        Pop-Location
        Set-Location ..\scripts
    }

    Write-Host ""
    Write-ColorOutput "=== Adding KIND cluster specific dependencies ==="
    Write-Host ""

    Write-ColorOutput "=== Adding kube metrics server Helm repo and updating ==="
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo update

    Write-ColorOutput "=== Installing metrics-server via HELM ==="
    helm upgrade --install --set args="{--kubelet-insecure-tls}" metrics-server metrics-server/metrics-server --namespace kube-system --version 3.13.0
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-ColorOutput "=== Installing kube-state-metrics via Helm ==="
    helm install --wait kube-state-metrics prometheus-community/kube-state-metrics -n kube-system --version 6.4.1
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-ColorOutput "=== Applying promethus and annotation based scraping rules manfest ==="
    kubectl apply -f .\kind\prometheus.yaml
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s
    if ($LASTEXITCODE -ne 0) { exit 1 }

    if ($PRIVATE_NETWORK -eq "false") {
        Write-ColorOutput "=== Installing nginx ingress controller designed for KIND ==="
        kubectl apply -f .\kind\ingress-nginx.yaml
        if ($LASTEXITCODE -ne 0) { exit 1 }
        
        Write-ColorOutput "=== Waiting for nginx ingress controller to be ready ==="
        kubectl wait --namespace ingress-nginx `
            --for=condition=ready pod `
            --selector=app.kubernetes.io/component=controller `
            --timeout=120s
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    if ($PRIVATE_NETWORK -eq "true") {
        Write-ColorOutput "=== Pulling KIND cloud-provider-kind load balancer for KIND cluster ==="
        docker pull registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.7.0
        if ($LASTEXITCODE -ne 0) { exit 1 }
        
        docker tag registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.7.0 cloud-controller-manager:v0.7.0
        if ($LASTEXITCODE -ne 0) { exit 1 }
    }

    Write-ColorOutput "=== Installing workload ==="

    if ($PRIVATE_NETWORK -eq "true") {
        $values_file = "values-localdev-lb.yaml"
    } else {
        $values_file = "values-localdev-ingress.yaml"
    }

    helm upgrade --install kedascalerapp ..\workload\chart --namespace default --create-namespace -f ..\workload\values-base.yaml -f ..\workload\$values_file --set-string githubTokenSecret.token=$GITHUBTOKEN --set privateNetwork.enabled=$PRIVATE_NETWORK
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-ColorOutput "=== Installation complete! ==="
    Write-Host ""
    Write-ColorOutput "=== To remove cluster/deployment - run .\localdev\delete-localdev.ps1 ==="
} finally {
    Pop-Location
}