param env string
param appname string
param tags object

resource loganaltyics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'la-${appname}-${env}'
  location: resourceGroup().location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    features: {
      immediatePurgeDataOn30Days: env == 'prod' ? false : true
    }
  }
}

output name string = loganaltyics.name
