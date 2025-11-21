#!/bin/bash
# Install general k8s cluster dependencies for the workload (KEDA, Prometheus Operator CRDs) 

echo -e "${GREEN}=== General k8s Cluster dependency deployment starting. ===${NC}"
echo -e ""
echo -e "${GREEN}=== Adding HELM repos for Prometheus and KEDA and updating ===${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
echo -e ""
echo -e "${GREEN}=== Installing Prometheus CRDs via HELM (required by KEDA) ===${NC}"
echo -e ""
helm install --wait prometheus-operator-crds prometheus-community/prometheus-operator-crds -n kube-system --version 24.0.2
echo -e ""
echo -e "${GREEN}=== Installing KEDA via Helm with promethus scrape annotations ===${NC}"
echo -e ""
helm install --wait keda kedacore/keda --namespace keda --create-namespace --set serviceAccount.create=false --version 2.18.1 --set serviceAccount.name=keda-operator --set podIdentity.azureWorkload.enabled=true --set podIdentity.azureWorkload.clientId=$KEDAUSERASSIGNEDIDENTITYCLIENTID --set podIdentity.azureWorkload.tenantId=$AZURE_TENANT_ID --set meta.helm.sh/release-namespace=helm --set prometheus.operator.enabled=true --set prometheus.metricServer.enabled=true --set prometheus.operator.serviceMonitor.enabled=true --set prometheus.metricServer.serviceMonitor.enabled=true
kubectl patch deployment keda-operator -n keda -p '{"spec": {"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/path":"/metrics","prometheus.io/port":"8080"}}}}}'
echo -e ""
echo -e "${GREEN}=== General k8s Cluster dependency deployment finished. ===${NC}"
echo -e ""