param env string
param appname string
param tags object

module loganaltyics 'br/public:avm/res/operational-insights/workspace:0.14.0' = {
  name: 'loganaltyics-avm'
  params: {
    name: 'la-${appname}-${env}'
    location: resourceGroup().location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    dailyQuotaGb: 1
    features: {
      immediatePurgeDataOn30Days: env == 'prod' ? false : true
    }
  }
}

output name string = loganaltyics.name
