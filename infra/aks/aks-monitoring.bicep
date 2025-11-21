param logWorkspaceName string
param monitorWorkspaceName string
param tags object
param clustername string
param diagnosticsRules array

resource managedCluster 'Microsoft.ContainerService/managedClusters@2025-07-02-preview' existing = {
  name: clustername
}


var location string = resourceGroup().location

resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: 'dce-${clustername}'
  location: location
  kind: 'Linux'
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
  tags: tags
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-${clustername}'
  kind: 'Linux'
  location: location
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoint.id
    dataSources: {
      prometheusForwarder: [
        {
          name: 'PrometheusDataSource'
          streams: [
            'Microsoft-PrometheusMetrics'
          ]
          labelIncludeFilter: {}
        }
      ]
    }
    destinations: {
      monitoringAccounts: [
        {
          accountResourceId: resourceId(resourceGroup().name, 'Microsoft.Monitor/accounts', monitorWorkspaceName)
          name: monitorWorkspaceName
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-PrometheusMetrics'
        ]
        destinations: [
          monitorWorkspaceName
        ]
      }
    ]
  }
  tags: tags
}

var logworkspaceId = resourceId(resourceGroup().name, 'Microsoft.OperationalInsights/workspaces', logWorkspaceName)

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: dataCollectionRule
  name: 'default'
  properties: {
    workspaceId: logworkspaceId
    logs: diagnosticsRules
    logAnalyticsDestinationType: 'AzureDiagnostics'
  }
}

resource dataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11'  = {
  name: 'dcra-${clustername}'
  dependsOn: [ diagnosticSettings ]
  scope: managedCluster
  properties: {
    dataCollectionRuleId: dataCollectionRule.id
  }
}
