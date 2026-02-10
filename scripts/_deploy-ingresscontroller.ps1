# Basic ingress for Azure

Write-Host "=== Installing basic ingress-nginx implementation from /cluster-dependencies/general/ingress-nginx ===" -ForegroundColor Green

Push-Location
try {
    Set-Location ..\cluster-dependencies\general\ingress-nginx
    
    $result = & .\install.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "=== Ingress installation failed, exiting. ==="
        exit 1
    }
}
finally {
    Pop-Location
    Set-Location ..\scripts
}

Write-Host "=== Ingress installation completed successfully. ===" -ForegroundColor Green
