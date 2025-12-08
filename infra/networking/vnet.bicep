param networkAddressSpace string
param tags object
param name string
param subnets array

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
  }
}

output aksSubnetId string = vnet.outputs.subnetResourceIds[0]
