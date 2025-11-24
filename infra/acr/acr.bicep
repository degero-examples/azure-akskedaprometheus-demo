param name string
param tags object
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string

module acr 'br/public:avm/res/container-registry/registry:0.9.3' = {
  name: 'acr'
  params: {
    name: name
    location: resourceGroup().location
    tags: tags
    acrSku: sku
    acrAdminUserEnabled: true
    quarantinePolicyStatus: 'disabled'
    trustPolicyStatus: 'disabled'
    retentionPolicyStatus: 'disabled'
    exportPolicyStatus: 'enabled'
    azureADAuthenticationAsArmPolicyStatus: 'enabled'
    softDeletePolicyStatus: 'disabled'
    softDeletePolicyDays: 7
    dataEndpointEnabled: sku == 'Premium' ? true : false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
  }
}

output name string = acr.name
