#!/bin/bash
# Upload /workload/volume-data for demonstration nginx apps to server the html

echo -e "${GREEN}=== Voluemdata upload started. ===${NC}"

az storage file upload --account-name $AZFILESACNAME --account-key $AZFILESSECRET --share-name $AZFILESSHARE_APPONE --source ../workload/volume-data/app-one/index.html --path index.html
az storage file upload --account-name $AZFILESACNAME --account-key $AZFILESSECRET --share-name $AZFILESSHARE_APPTWO --source ../workload/volume-data/app-two/index.html --path index.html

echo -e "${GREEN}=== Voluemdata upload started. ===${NC}"
