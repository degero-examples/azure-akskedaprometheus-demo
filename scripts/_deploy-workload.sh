#!/bin/bash
# Deploy app workload with Azure specific settings

echo -e "${GREEN}=== Workload deployment starting. ===${NC}"

if [ "$PRIVATE_NETWORK" = "true" ]; then
    values_file="values-azure-lb.yaml"
else
    values_file="values-azure-ingress.yaml"
fi

# Set ingressclass if approuting addon turned on in AKS
if [ "$USE_AKS_APP_ROUTING_ADDON" = "true" ]; then
    ingress_class="webapprouting.kubernetes.azure.com"
else
    ingress_class="ingress-nginx-basic"
fi

helm upgrade --install $APPNAME ../workload/chart --namespace default  --create-namespace -f ../workload/values-base.yaml \
 -f ../workload/$values_file --set githubTokenSecret.token=$GITHUBTOKEN --set azureFilesSecret.accountKey=$AZFILESSECRET \
 --set azureFilesSecret.accountName=$AZFILESACNAME --set workloadIdentity.clientId=$KEDAUSERASSIGNEDIDENTITYCLIENTID \
 --set kedaPrometheusAccess.serverAddress=$PROMETHEUSQUERYENDPOINT --set privateNetwork.enabled=$PRIVATE_NETWORK \
 --set ingress.ingressClassName=$ingress_class --set ingress.aksManaged=$USE_AKS_APP_ROUTING_ADDON \
 --set ingress.host=$INGRESS_HOST --set volumes[0].shareName="$AZFILESSHARE_APPONE" \
 --set volumes[1].shareName="$AZFILESSHARE_APPTWO"

echo -e "${GREEN}=== Workload deployment completed successfully! ===${NC}"
