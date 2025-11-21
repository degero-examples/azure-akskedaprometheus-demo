param appname string
param env string
param acrName string

var roleIds = loadJsonContent('../_defs/roles.json')
var principalName = 'mi-kubelet-aks-${appname}-${env}'
var roleObj = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.Containers.AcrPull)

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: principalName
}

resource acr 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' existing = {
  name: acrName
}

// Allow Kubelet User Assigned Identity access to pull from ACR
resource roleAssignmentMonitorReaderKeda 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appname, env, principalName, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: roleObj
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
