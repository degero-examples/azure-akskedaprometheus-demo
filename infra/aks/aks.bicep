param clustername string
param tags object
param logWorkspaceName string
param monitorWorkspaceName string
param clusterSKU string
param nodePools array
param agentPoolMaxCount int
param agentPoolVMSize string
param enablePrivateNetwork bool
param privateVNetSubnetId string
param enableAKSAppRoutingAddon bool 

var location string = resourceGroup().location

module dataCollectionEndpoint 'br/public:avm/res/insights/data-collection-endpoint:0.5.1' = {
  name: 'dce-avm-${clustername}'
  params: {
    name: 'dce-${clustername}'
    location: location
    tags: tags
    kind: 'Linux'
    publicNetworkAccess: 'Enabled'
  }
}


module dataCollectionRule 'br/public:avm/res/insights/data-collection-rule:0.9.0' = {
  name: 'dcr-avm-${clustername}'
  params: {
    name: 'dcr-${clustername}'
    location: location
    tags: tags
    dataCollectionRuleProperties: {
      kind: 'Linux'
      dataCollectionEndpointResourceId: dataCollectionEndpoint.outputs.resourceId
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
  }
}

var logworkspaceId = resourceId(resourceGroup().name, 'Microsoft.OperationalInsights/workspaces', logWorkspaceName)

resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' existing = {
  name: dataCollectionRule.name
}

// AVM not used as no tags param
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: dcr
  name: 'default'
  properties: {
    workspaceId: logworkspaceId
    logs: [
      // enable these as preferred
      // {
      //   categoryGroup: 'allLogs'
      //   enabled: true  
      // }
      // {
      //   category: 'cluster-autoscaler'
      //   enabled: true
      // }
      // {
      //   category: 'kube-controller-manager'
      //   enabled: true
      // }
      // {
      //   category: 'kube-audit-admin'
      //   enabled: true
      // }
      // {
      //   category: 'guard'
      //   enabled: true
      // }
      // {
      //   category: 'kube-scheduler'
      //   enabled: false // Only enable while tuning or triaging issues with scheduling. On a normally operating cluster there is minimal value, relative to the log capture cost, to keeping this always enabled.
      // }
    ]
    logAnalyticsDestinationType: 'AzureDiagnostics'
  }
}



// AKS cluster User assigned identity
module aksUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = {
  name: 'ident-avm-mi-${clustername}'
  params: {
    name: 'mi-${clustername}'
    location: location
    tags: tags
  }
}

// Kubelenet User assigned identity
module kubeletUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = {
  name: 'ident-avm-mi-kubelet-${clustername}'
  params: {
    name: 'mi-kubelet-${clustername}'
    location: location
    tags: tags
  }
}

// Workload User assigned identity for keda
module kedaUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = {
  name: 'ident-avm-mi-keda-${clustername}'
  dependsOn: [ managedCluster ]
  params: {
    name: 'mi-keda-${clustername}'
    location: location
    tags: tags
  }
}

// Assign Roles eg Managed Identity Operator to allow AKS to assign kubelet identity to nodes
module kubeletRoleAssignemnt 'aks-auth.bicep' = {
  name: 'kubeletRoleAssignemnt-${clustername}'
  params: {
    clusterIdentityName: aksUserAssignedIdentity.outputs.name
    kubeletIdentityName: kubeletUserAssignedIdentity.outputs.name
  }
}

module managedCluster 'br/public:avm/res/container-service/managed-cluster:0.11.1' = {
  name: 'aks-avm-${clustername}'
  dependsOn: [ kubeletRoleAssignemnt ]
  params: {
    name: clustername
    location: location
    tags: tags
    skuName:'Base'
    skuTier: clusterSKU
    managedIdentities: {
      userAssignedResourceIds: [ aksUserAssignedIdentity.outputs.resourceId ]
    }  
    dnsPrefix: '${clustername}-dns'
    enableAzureMonitorProfileMetrics: true
    primaryAgentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1 
        minCount: 1
        maxCount: agentPoolMaxCount
        vmSize: agentPoolVMSize
        osDiskSizeGB: 30
        osDiskType: 'Ephemeral'
        kubeletDiskType: 'OS'
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: true
        scaleDownMode: 'Delete'
        powerState: {
          code: 'Running'
        }
        enableNodePublicIP: false
        tags: tags
        mode: 'System'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        upgradeSettings: {
          maxSurge: '10%'
          maxUnavailable: '0'
        }
        enableFIPS: false
        securityProfile: {
          enableVTPM: false
          enableSecureBoot: false
        }
        availabilityZones: null
        vnetSubnetID: enablePrivateNetwork ? privateVNetSubnetId : null
      }
    ]
    aksServicePrincipalProfile: {
      clientId: 'msi'
    }
    enableKeyvaultSecretsProvider: false
    azurePolicyEnabled: false
    aciConnectorLinuxEnabled: false
    omsAgentEnabled: true
    omsAgentUseAADAuth: true
    monitoringWorkspaceResourceId: logworkspaceId
    nodeResourceGroup: 'MC-${clustername}'
    enableRBAC: true
    networkPlugin: 'azure'
    networkPluginMode: 'overlay'
    networkPolicy: 'azure'
    networkDataplane: 'azure'
    loadBalancerSku: 'standard'
    managedOutboundIPCount: 1
    backendPoolType: 'NodeIPConfiguration'
    podCidr: '10.244.0.0/16' 
    serviceCidr: '10.0.0.0/16'
    dnsServiceIP: '10.0.0.10'
    outboundType: 'loadBalancer'

    // Agressive scaledown profile for cost savings
    autoScalerProfileScaleDownDelayAfterAdd: '5m'
    autoScalerProfileScaleDownDelayAfterDelete: '10s'
    autoScalerProfileScaleDownDelayAfterFailure: '3m'
    autoScalerProfileScaleDownUnneededTime: '5m'
    autoScalerProfileScaleDownUnreadyTime: '5m'
    autoScalerProfileSkipNodesWithLocalStorage: false
    autoScalerProfileSkipNodesWithSystemPods: true
    autoScalerProfileBalanceSimilarNodeGroups: false
    autoScalerProfileIgnoreDaemonsetsUtilization: true
    autoScalerProfileDaemonsetEvictionForOccupiedNodes: true
    autoScalerProfileExpander: 'random'
    autoScalerProfileUtilizationThreshold: '0.5'
    autoScalerProfileMaxEmptyBulkDelete: 10
    autoScalerProfileMaxGracefulTerminationSec: 600
    autoScalerProfileMaxNodeProvisionTime: '15m'
    autoScalerProfileMaxTotalUnreadyPercentage: 45
    autoScalerProfileNewPodScaleUpDelay: '0s'
    autoScalerProfileOkTotalUnreadyCount: 3
    autoScalerProfileScanInterval: '30s'

    autoNodeOsUpgradeProfileUpgradeChannel: 'NodeImage'
    autoUpgradeProfileUpgradeChannel: 'patch'
    disableLocalAccounts: false
    identityProfile: { 
      kubeletIdentity: {
        resourceId: kubeletUserAssignedIdentity.outputs.resourceId
        clientId: kubeletUserAssignedIdentity.outputs.clientId
        objectId: kubeletUserAssignedIdentity.outputs.principalId
      }
    }

    // Use the AKS managed app routing (nginx ingress controller) in PROD only if not using private net. 
    // This allows IP based requests to show up in metrics (see issue here: https://github.com/Azure/AKS/issues/5216)
    webApplicationRoutingEnabled: enableAKSAppRoutingAddon
    enableImageCleaner: true
    imageCleanerIntervalHours: 168
    enableWorkloadIdentity: true

    // Allow Disk or Azure files PV / PVC
    enableStorageProfileDiskCSIDriver: true
    enableStorageProfileFileCSIDriver: true
    enableStorageProfileSnapshotController: true

    enableOidcIssuerProfile: true
    kedaAddon: false // This Uses a custom KEDA in the workload not the addon due to dependency issues / managed identity
    costAnalysisEnabled: false // enable for cost analysis recommended in prod only

    // User pools
    agentPools: [ for n in nodePools : {
        name: n.name
        count: n.count
        vmSize: n.sku
        maxCount: n.maxCount
        minCount: n.minCount
        osDiskSizeGB: 30
        osDiskType: 'Ephemeral'
        kubeletDiskType: 'OS'
        workloadRuntime: 'OCIContainer'
        maxPods: 250
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets' // Use scale sets so nodes can scale on KEDA hpa demand
        availabilityZones: []
        scaleDownMode: 'Delete'
        enableNodePublicIP: false
        nodeLabels: n.nodeLabels
        mode: 'User'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        enableFIPS: false
        enableVTPM: false
        enableSecureBoot: false
        vnetSubnetResourceId: enablePrivateNetwork ? privateVNetSubnetId : null
      }
    ]

    maintenanceConfigurations: [
      {
        name: 'aksManagedAutoUpgradeSchedule'
        maintenanceWindow: {
          schedule: {
            weekly: {
              intervalWeeks: 1
              dayOfWeek: 'Sunday'
            }
          }
          durationHours: 8
          utcOffset: '+00:00'
          startDate: '2025-11-12'
          startTime: '00:00'
        }
      }
      {
        name: 'aksManagedNodeOSUpgradeSchedule'
        maintenanceWindow: {
          schedule: {
            weekly: {
              intervalWeeks: 1
              dayOfWeek: 'Sunday'
            }
          }
          durationHours: 8
          utcOffset: '+00:00'
          startDate: '2025-11-12'
          startTime: '00:00'
        }
      }
    ]
  }
}

resource cluster 'Microsoft.ServiceFabric/managedClusters@2025-06-01-preview' existing = {
  dependsOn: [ managedCluster]
  name: clustername
}

resource dataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'dcra-${clustername}'
  dependsOn: [ diagnosticSettings ]
  scope: cluster
  properties: {
    dataCollectionRuleId: dataCollectionRule.outputs.resourceId
  }
}

resource kedaIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  dependsOn: [ kedaUserAssignedIdentity ]
  name: 'mi-keda-${clustername}'
}

// Create federated identity needed for keda workload to access azure monitor
resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
    name: 'fed-${kedaUserAssignedIdentity.name}'
    parent: kedaIdentity
    properties: {
        issuer: managedCluster.outputs.oidcIssuerUrl!
        subject: 'system:serviceaccount:keda:keda-operator'
        audiences: [
            'api://AzureADTokenExchange'
        ]
    }
}

output aksUserAssignedIdentityName string = aksUserAssignedIdentity.outputs.name
output kubeletUserAssignedIdentityName string = kubeletUserAssignedIdentity.outputs.name
output kedaUserAssignedIdentityName string = kedaUserAssignedIdentity.outputs.name
output kedaUserAssignedIdentityClientId string = kedaUserAssignedIdentity.outputs.clientId
output oidcIssuerProfileissuerUrl string = managedCluster.outputs.oidcIssuerUrl!
output kedaFederatedIdentityName string = 'fed-${kedaUserAssignedIdentity.name}'
