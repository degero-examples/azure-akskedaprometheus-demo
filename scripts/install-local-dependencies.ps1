function Test-CommandExists {
    param($Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-Helm {
    if (Test-CommandExists "helm") {
        Write-Host "helm is already installed."
        return
    }

    Write-Host "Installing Dependency: helm..."
    if ($IsWindows -or $env:OS -match "Windows") {
        # Windows
        if (Test-CommandExists "winget") {
            winget install Helm.Helm --accept-package-agreements
        }
        elseif (Test-CommandExists "choco") {
            choco install kubernetes-helm -y
        }
        else {
            Write-Host "Please install winget or chocolatey, or manually install Helm from https://helm.sh/docs/intro/install/"
        }
    }
    elseif ($IsMacOS) {
        # macOS
        if (Test-CommandExists "brew") {
            brew install kubectl
        }
        else {
            Write-Host "Please install Homebrew first: https://brew.sh"
        }
    }
    elseif ($IsLinux) {
        # Linux
        $stableVersion = Invoke-RestMethod -Uri "https://dl.k8s.io/release/stable.txt"
        $kubectlUrl = "https://dl.k8s.io/release/$stableVersion/bin/linux/amd64/kubectl"
        
        Invoke-WebRequest -Uri $kubectlUrl -OutFile "./kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        kubectl version --client
    }
    else {
        Write-Host "Unsupported operating system"
    }
}

function Install-Kubectl {
    if (Test-CommandExists "kubectl") {
        Write-Host "kubectl is already installed."
        return
    }

    Write-Host "Installing Dependency: kubectl..."
    
    if ($IsWindows -or $env:OS -match "Windows") {
        # Windows
        if (Test-CommandExists "winget") {
            winget install Kubernetes.kubectl --accept-package-agreements
        }
        elseif (Test-CommandExists "choco") {
            choco install kubernetes-cli -y
        }
        else {
            Write-Host "Please install winget or chocolatey, or manually install kubectl"
        }
    }
    elseif ($IsMacOS) {
        # macOS
        if (Test-CommandExists "brew") {
            brew install kubectl
        }
        else {
            Write-Host "Please install Homebrew first: https://brew.sh"
        }
    }
    elseif ($IsLinux) {
        # Linux
        $stableVersion = Invoke-RestMethod -Uri "https://dl.k8s.io/release/stable.txt"
        $kubectlUrl = "https://dl.k8s.io/release/$stableVersion/bin/linux/amd64/kubectl"
        
        Invoke-WebRequest -Uri $kubectlUrl -OutFile "./kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        kubectl version --client
    }
    else {
        Write-Host "Unsupported operating system"
    }
}

# Main execution
Install-Helm
Install-Kubectl

Write-Host "Dependency check complete."
