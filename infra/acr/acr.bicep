param name string
param tags object
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string
param appname string
param env string

var roleIds = loadJsonContent('../_defs/roles.json')
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: 'mi-kubelet-aks-${appname}-${env}'
}

module acr 'br/public:avm/res/container-registry/registry:0.9.3' = {
  name: 'acr'
  params: {
    name: name
    location: resourceGroup().location
    tags: tags
    acrSku: sku
    roleAssignments: [
      {
        roleDefinitionIdOrName: roleIds.Containers.AcrPull
        principalId: aksIdentity.properties.principalId
        principalType: 'ServicePrincipal'
      }
    ]
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
