
param appname string
param env string

var roleIds = loadJsonContent('../_defs/roles.json')
var principalName = 'mi-aks-${appname}-${env}'

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: principalName
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: 'vnet-${appname}-${env}'
}

var roleObj = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.Networking['Network Contributor'])

var networkContribRole = 'Network Contributor'
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appname, env, principalName, networkContribRole)
  scope: vnet
  properties: {
    roleDefinitionId: roleObj
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
