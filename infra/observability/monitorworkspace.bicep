param env string
param appname string
param tags object

resource monitorworkspace 'Microsoft.Monitor/accounts@2025-05-03-preview' = {
  name: 'amw-${appname}-${env}'
  location: resourceGroup().location
  tags: tags
}

output name string = monitorworkspace.name
output id string = monitorworkspace.id
output prometheusQueryEndpoint string = monitorworkspace.properties.metrics.prometheusQueryEndpoint
