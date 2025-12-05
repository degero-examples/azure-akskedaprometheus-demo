param appname string
param env string

@description('Ingress via VNET with internal load balancer')
param enablePrivateNetwork bool

@description('Add a managed grafana instance')
param enableGrafana bool

@description('Grafana users to be added to the managed grafana instance')
param grafanaUsers array = []

@description('Add container registry for workloads with privately deployed containers')
param enableContainerRegistry bool

@description('Enable AKS managed app routing addon (nginx ingress)')
param enableAKSAppRoutingAddon bool

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param continerRegistrySku string = 'Basic'

@description('Node pools configuration')
param nodePools array

@description('Max agent pool nodes, min is always 1')
param agentPoolMaxCount int

param agentPoolVMSize string

@description('AKS cluster SKU')
@allowed([
  'Free'
  'Standard'
  'Premium'
])
param clusterSKU string

var tags object = {
  environment: env
  appname: appname
}

module logworkspace './observability/logworkspace.bicep' = {
  name: 'logworkspace'
  params: {
    appname: appname
    env: env
    tags: tags
  }
}

module monitorworkspace './observability/monitorworkspace.bicep' = {
  name: 'monitorworkspace'
  params: {
    appname: appname
    env: env
    tags: tags
  }
}

// VNet for private ingress
module networking './networking/module.bicep' = if (enablePrivateNetwork) {
  name: 'networking'
  params: {
    appname: appname
    env: env
    tags: tags
  }
}

var aksSubnetId = enablePrivateNetwork ? networking!.outputs.aksSubnetId ?? '' : ''

var clusterName = 'aks-${appname}-${env}'
// module aks './aks/aks.bicep' = {
//   name: 'aks'
//   params: {
//     tags: tags
//     clustername: clusterName
//     clusterSKU: clusterSKU
//     nodePools: nodePools
//     agentPoolMaxCount: agentPoolMaxCount
//     agentPoolVMSize: agentPoolVMSize
//     enablePrivateNetwork: enablePrivateNetwork
//     privateVNetSubnetId: aksSubnetId
//     logWorkspaceName: logworkspace.outputs.name
//     monitorWorkspaceName: monitorworkspace.outputs.name
//     enableAKSAppRoutingAddon: enableAKSAppRoutingAddon
//   }
// }

// There are no alerts added or container insights/container logs collected, 
// just metrics (and diagnostic logs if you enable below).
// Enabling prometheus / monitor alerts is highly recoomended for PROD
// See the AKS baseline in github for ContianerInsights/Logs bicep
// module aksMonitoring './aks/aks-monitoring.bicep' = {
//   name: 'aksMonitoring'
//   dependsOn: [aks]
//   params: {
//     clustername: clusterName
//     logWorkspaceName: logworkspace.outputs.name
//     monitorWorkspaceName: monitorworkspace.outputs.name
//     tags: tags
//     diagnosticsRules: [
//       // enable these as needed - recommended mainly for enivonrment troubleshooting
//       // {
//       //   categoryGroup: 'allLogs'
//       //   enabled: true  
//       // }
//       // {
//       //   category: 'cluster-autoscaler'
//       //   enabled: true
//       // }
//       // {
//       //   category: 'kube-controller-manager'
//       //   enabled: true
//       // }
//       // {
//       //   category: 'kube-audit-admin'
//       //   enabled: true
//       // }
//       // {
//       //   category: 'guard'
//       //   enabled: true
//       // }
//       // {
//       //   category: 'kube-scheduler'
//       //   enabled: false // Only enable while tuning or triaging issues with scheduling. On a normally operating cluster there is minimal value, relative to the log capture cost, to keeping this always enabled.
//       // }
//     ]
//   }
// }

// To allow ReadOnlyMany access to files (eg scaled up deployments)
var storageAccountName = 'st${toLower(take('${appname}${env}${uniqueString(resourceGroup().id, env)}', 22))}'

var fileShareNames = ['sh-aks-${appname}-appone-${env}', 'sh-aks-${appname}-apptwo-${env}']
module aksFiles './storage/azurefiles.bicep' = {
  name: 'aksFiles'
  params: {
    storageAccountName: storageAccountName
    fileShareNames: fileShareNames
    tags: tags
    deletedFileRetentionDays: 0 // disable delete retention, > 0 enables it
    shareSizeGb: 2
    shareTier: 'Hot'
    storageAccountSku: 'Standard_LRS' // use 'PremiumV2_LRS' for premium 
  }
}
var grafanaResourceName = 'amg${toLower(take(replace('${appname}${env}${uniqueString(resourceGroup().id)}', '-', ''), 20))}'

module grafana './observability/grafana.bicep' = if (enableGrafana) {
  name: 'grafana'
  params: {
    name: grafanaResourceName
    tags: tags
    grafanaUsers: grafanaUsers
    azureMonitorResourceId: monitorworkspace.outputs.id
  }
}

module azureMonitorAuth './observability/monitor-auth.bicep' = {
  name: 'aksRBAC'
  dependsOn: enableGrafana ? [networking, grafana] : [networking] //aks
  params: {
    appname: appname
    env: env
    grafanaIdentityPrincipalId: enableGrafana ? grafana!.outputs.grafanaIdentityPrincipalId : ''
  }
}

var acrResourceName = toLower(take('acr${replace('${appname}${env}${uniqueString(resourceGroup().id)}', '-', '')}', 50))

module acr './acr/acr.bicep' = if (enableContainerRegistry) {
  name: 'acr'
  params: {
    name: acrResourceName
    sku: continerRegistrySku
    tags: tags
    appname: appname
    env: env
  }
}


output azure_location string = resourceGroup().location
output azure_tenant_id string = tenant().tenantId
output appname string = appname
output env string = env
output clustername string = clusterName
output private_network bool = enablePrivateNetwork
output use_aks_app_routing_addon bool = enableAKSAppRoutingAddon
output azfilesacname string = storageAccountName
output azfilesshare_appone string = fileShareNames[0]
output azfilesshare_apptwo string = fileShareNames[1]
output resource_group string = resourceGroup().name
output kedaUserAssignedIdentityClientId string = ''//aks.outputs.kedaUserAssignedIdentityClientId
output prometheusQueryEndpoint string = monitorworkspace.outputs.prometheusQueryEndpoint
output grafanaResourceName string = enableGrafana ? grafana!.outputs.grafanaResourceName : ''
output acrResourceName string = enableContainerRegistry ? acr!.outputs.name : ''
