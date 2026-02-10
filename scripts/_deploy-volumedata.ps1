# Upload /workload/volume-data for demonstration nginx apps to serve the html

Write-Host "=== Volumedata upload started. ===" -ForegroundColor Green

az storage file upload --account-name $env:AZFILESACNAME --account-key $env:AZFILESSECRET --share-name $env:AZFILESSHARE_APPONE --source ..\workload\volume-data\app-one\index.html --path index.html
az storage file upload --account-name $env:AZFILESACNAME --account-key $env:AZFILESSECRET --share-name $env:AZFILESSHARE_APPTWO --source ..\workload\volume-data\app-two\index.html --path index.html

Write-Host "=== Volumedata upload completed. ===" -ForegroundColor Green
