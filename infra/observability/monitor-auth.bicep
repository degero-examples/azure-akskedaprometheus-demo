
param appname string

param env string

param grafanaIdentityPrincipalId string

var roleIds = loadJsonContent('../_defs/roles.json')
var roleObj = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.Monitor['Monitoring Reader'])

var clusterName = 'aks-${appname}-${env}'

resource kedaIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: 'mi-keda-${clusterName}'
}

resource monWorkspace 'Microsoft.Monitor/accounts@2023-10-01-preview' existing = {
  name: 'amw-${appname}-${env}'
}

// Allow KEDA access to Azure Monitor Prometheus metrics
resource roleAssignmentMonitorReaderKeda 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appname, env, 'mi-${clusterName}', 'Monitoring Reader')
  scope: monWorkspace
  properties: {
    roleDefinitionId: roleObj
    principalId: kedaIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// If Grafana is enabled grant it access to read metrics
resource roleAssignmentMonitorReaderGrafana 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (grafanaIdentityPrincipalId != '') {
  name: guid(appname, env, 'amg-${appname}-${env}', 'Monitoring Reader')
  scope: monWorkspace
  properties: {
    roleDefinitionId: roleObj
    principalId: grafanaIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
