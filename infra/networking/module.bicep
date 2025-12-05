param appname string
param env string
param tags object

// NSG to lock down to only 80/443 inbound / outbound for private ingress
module nsg './nsg.bicep' = {
  name: 'nsg'
  params: {
    name: 'nsg-${appname}-${env}'
    tags: tags
  }
}
 
module vnet './vnet.bicep' = {
  name: 'vnet'
  params: {
    appname: appname
    env: env
    name: 'vnet-${appname}-${env}'
    tags: tags
    networkAddressSpace: '10.240.0.0/12'
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.240.0.0/16'
          networkSecurityGroup: {
            id: nsg.outputs.id
          }
        }
      }
      {
        name: 'aks-private-ingress'
        properties: {
          addressPrefix: '10.241.0.0/16'
          networkSecurityGroup: {
            id: nsg.outputs.id
          }
        }
      }
      {
        // For higher envs its recommneded to be secured down with NSG/ASG
        name: 'virtualmachines'
        properties: {
          addressPrefix: '10.242.0.0/16'
        }
      }
    ]
  }
}

output aksSubnetId string = vnet.outputs.aksSubnetId
