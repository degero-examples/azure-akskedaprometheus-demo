# AKS infra

## Important

This is setup for ease of use/low cost trialing and is not security hardended nor suited for PROD use. Look at the [AKS baseline](https://github.com/mspnp/aks-baseline/blob/main/README.md) cluster deployment details for bicep with 'prod ready' cluster configurations. You could adopt those settings in if you wish to fork this. 

## Resources

- AKS cluster (Linux using AzureLinux container on nodes)
- User assigned Identities for Cluster, Kubelet and KEDA for enabling RBAC access to VNet, Azure Monitor, ACR
- CNI Options of Private ingress via CNI Pod subnet on VNet or Azure managed CNI Overlay for nginx ingress
- VNET on Address space 10.240.0.0/12, subnets for AKS cluster (10.240.0.0/16), app deployment (10.241.0.0/16) and virtual machines(10.242.0.0/16) (to access/test apps via VM)
- (Optional) Nginx ingress via [app routing AKS addon](https://learn.microsoft.com/en-us/azure/aks/app-routing)
- Log Workspace
- Azure Monitor workspace / Managed promethus
- Azure Managed Grafana (optional, with Azure monitor prometheus data source connected)
- Azure Files share for mulitpod R/W access
- Azure Container Registry (optional, sets up closter managed identity with AcrPull role)
- Data collection DCE / DCR prometheus metrics, AKS diagnostics

## Notes

- Custom resourcegroup MC-<clustername> used for cluster managed resources (load balancer, IP etc)
- Due to the configuration limitation on AKS app routing addon not outputting nginx metrics without a hostname, non prod envs not using a private network can use the custom nginx ingress controller included (unless you want add DNS registrations for non-prod IPs) Ensure enableAKSAppRoutingAddon=false to make use of this.

## Configuration

Copy default.bicepparam.sample to default.bicepparam and make adjustments as needed:

- If you wish to use ACR, enable the bicepparam, push your image to the ACR and update /workload/values-base.yaml image name/ver
- If you with to use Grafana, enable the bicepparam and add user Principal IDs to with the sample role types (note it takes a few minutes for grafana to update with the access permissions)
- To restrict access to the app to only a VNET, set enablePrivateNetwork=true
- If you set enableAKSAppRoutingAddon=true do not set enablePrivateNetwork=true
- You can alter the appname / env to your liking (ensure you follow the notes in the workload to update your env file with these)

## Auto Deploy

See guide in project [README.md](../README.md) to auto deploy using Azure Developer CLI

## Manual Deploy

Firstly ensure you:
- Based on preference, to keep in naming conventions set your resource group name below based on your env / appname choices above in the syntax rg-{appname}-{env}
- cp default.bicepparam.sample default.bicepparam
- update settings in default.bicepparam (eg: ingress or loadbalancer, grafana, acr etc)
- Have contributor role on target subscription
- [AZ CLI installed](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) and logged into azure (az login)
- az bicep install
- az bicep upgrade
- decide on a location, you can get a list with 'az account list-locations --query "[].name" --output tsv'
- run ./deploy-bicep.sh

## After Deployment

Go to the /workload folder and follow the steps in the [README.md](../workload/README.md)

When you are done testing the deployment you can either stop the AKS instance or delete the whole resource group to not incur unwanted costs (note there are other resources: storage, public IP etc that will have costs even if you stop AKS).