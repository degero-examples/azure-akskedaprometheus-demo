param clusterIdentityName string
param kubeletIdentityName string

resource kubeletUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: kubeletIdentityName
}
  
resource aksUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: clusterIdentityName
}

// Assign Managed Identity Operator role to the AKS cluster identity so it can assign the kubelet identity to nodes
var roleIds = loadJsonContent('../_defs/roles.json')
resource kubeletRoleAssignemnt 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(clusterIdentityName, kubeletUserAssignedIdentity.name, 'Managed Identity Operator')

  scope: kubeletUserAssignedIdentity
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.Identity['Managed Identity Operator'])
    principalId: aksUserAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
