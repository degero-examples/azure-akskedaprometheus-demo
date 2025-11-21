#!/bin/bash
# Basic ingress for Azure

echo -e "${GREEN}=== Installing basic ingress-nginx implementation from /cluster-dependencies/general/ingress-nginx ===${NC}"
cd ../cluster-dependencies/general/ingress-nginx  || exit 1
if ! bash ./install.sh; then
    echo -e "${GREEN}=== Ingress installation failed, exiting. ===${NC}" >&2
    exit 1
fi
cd ../../../scripts
echo -e "${GREEN}=== Ingress installation completed successfully. ===${NC}"
