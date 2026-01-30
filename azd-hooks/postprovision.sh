#!/bin/bash
# Post-provision hook to setup auth and deploy workload after infrastructure is set up

# Colors for output
export GREEN='\033[0;32m'
export NC='\033[0m' # No Colorsource

cd scripts || exit 1

echo -e ""

rm -f ./env.azure
azd env get-values > ./.env.azure

# This is written for manual script runs in /scripts to access (eg undeploy)
echo -e "${GREEN}=== Env vars updated to /scripts/.env.azure"
echo -e ""
echo -e "${GREEN}=== Installing local dependencies"

# need helm and kubectl for workload deploy
if ! bash ./install-local-dependencies.sh; then
    echo -e "${GREEN}=== Local dependency install failed, exiting. ===${NC}" >&2
    exit 1
fi

echo -e ""
echo -e "${GREEN}=== Workload deployment starting"

if ! bash ./deploy-azure-workload.sh; then
    echo -e "${GREEN}=== Workload deployment failed, exiting. ===${NC}" >&2
    exit 1
fi

cd .. || exit 1