param networkAddressSpace string
param tags object
param name string
param subnets array
param appname string
param env string

var principalName = 'mi-aks-${appname}-${env}'

resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: principalName
}

module vnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'vnet-avm'
  params: {
    name: name
    location: resourceGroup().location
    tags: tags
    addressPrefixes: [
      networkAddressSpace
    ]
    subnets: subnets
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Network Contributor'
        principalType: 'ServicePrincipal'
        principalId: aksIdentity.properties.principalId
      }
    ]
  }
}

output aksSubnetId string = vnet.outputs.subnetResourceIds[0]
