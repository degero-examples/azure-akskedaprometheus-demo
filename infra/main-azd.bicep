targetScope = 'subscription'

@allowed(['dev','staging','uat','test','devtest','prod'])
param environmentName string 
param location string 

@description('A name for you app to use resouce naming convention of <resourcetypecode>-<appname>-<>')
param appname string

@description('Ingress via VNET with internal load balancer')
param enablePrivateNetwork bool

@description('Add a managed grafana instance')
param enableGrafana bool

@description('Add container registry for workloads with privately deployed containers')
param enableContainerRegistry bool

@description('Enable AKS managed app routing addon (nginx ingress)')
param enableAKSAppRoutingAddon bool

@description('AKS cluster SKU')
@allowed([
  'Free'
  'Standard'
  'Premium'
])
param clusterSKU string

@description('VM size used for agent and user pools')
param vmSize string 

@description('Maximum agent pool node instances')
param agentPoolMaxCount int

@description('User node pools to create')
param nodePools array

@description('Array of userIds and Roles to access Grafana')
param grafanaUsers array

var resourceGroupName = 'rg-${appname}-${environmentName}'

var tags object = {
  environment: environmentName
  appname: appname
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    ...tags 
    'azd-env-name': environmentName
  }
}

module main 'main.bicep' = {
  name: 'main'
  scope: rg
  params: {
    agentPoolVMSize: vmSize
    grafanaUsers: grafanaUsers
    appname: appname
    env: environmentName
    enablePrivateNetwork: enablePrivateNetwork
    enableGrafana: enableGrafana
    enableContainerRegistry: enableContainerRegistry
    enableAKSAppRoutingAddon: enableAKSAppRoutingAddon
    continerRegistrySku: 'Basic'
    nodePools: nodePools
    agentPoolMaxCount: agentPoolMaxCount
    clusterSKU: clusterSKU
  }
}

output AZURE_TENANT_ID string = tenant().tenantId
output APPNAME string = appname
output ENV string = environmentName
output CLUSTERNAME string = main.outputs.clustername
output PRIVATE_NETWORK bool = main.outputs.private_network
output USE_AKS_APP_ROUTING_ADDON bool = main.outputs.use_aks_app_routing_addon
output AZFILESACNAME string = main.outputs.azfilesacname
output AZFILESSHARE_APPONE string = main.outputs.azfilesshare_appone
output AZFILESSHARE_APPTWO string = main.outputs.azfilesshare_apptwo
output RESOURCE_GROUP string = resourceGroupName
output AZURE_RESOURCE_GROUP string = resourceGroupName
output KEDAUSERASSIGNEDIDENTITYCLIENTID string = main.outputs.kedaUserAssignedIdentityClientId
output PROMETHEUSQUERYENDPOINT string = main.outputs.prometheusQueryEndpoint
output GRAFANARESOURCENAME string = main.outputs.grafanaResourceName
output ACRRESOURCENAME string = main.outputs.acrResourceName
