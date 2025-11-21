param networkAddressSpace string
param tags object
param name string
param subnets array

resource vnet 'Microsoft.Network/virtualNetworks@2024-10-01' = {
  name: name
  location: resourceGroup().location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkAddressSpace
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: subnets
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

output aksSubnetId string = vnet.properties.subnets[0].id
