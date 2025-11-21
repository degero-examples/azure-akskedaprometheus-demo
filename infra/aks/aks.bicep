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

resource dataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'dcra-${clustername}'
  dependsOn: [ diagnosticSettings ]
  scope: managedCluster
  properties: {
    dataCollectionRuleId: dataCollectionRule.id
  }
}

// AKS cluster User assigned identity
resource aksUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'mi-${clustername}'
  location: location
  tags: tags
}

// Kubelenet User assigned identity
resource kubeletUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'mi-kubelet-${clustername}'
  location: location
  tags: tags
}

// Workload User assigned identity for keda
resource kedaUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  dependsOn: [ managedCluster]
  name: 'mi-keda-${clustername}'
  location: location
  tags: tags
}

// Assign Roles eg Managed Identity Operator to allow AKS to assign kubelet identity to nodes
module kubeletRoleAssignemnt 'aks-auth.bicep' = {
  name: 'kubeletRoleAssignemnt-${clustername}'
  params: {
    clusterIdentityName: aksUserAssignedIdentity.name
    kubeletIdentityName: kubeletUserAssignedIdentity.name
  }
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2025-07-02-preview' = {
  name: clustername
  dependsOn: [ kubeletRoleAssignemnt ]
  location: location
  tags: tags
  sku: {
    tier: clusterSKU
    name: 'Base'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksUserAssignedIdentity.id}': {}
    }
  }
  properties: {
    dnsPrefix: '${clustername}-dns'
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {}
      }
    }
    agentPoolProfiles: [
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
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: false
      }
      azurepolicy: {
        enabled: false
      }
      aciConnectorLinux: {
        enabled: false
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logworkspaceId
          useAADAuth: 'true'
        }
      }
    }
    nodeResourceGroup: 'MC-${clustername}'
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      networkDataplane: 'azure'
      loadBalancerSku: 'standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
        backendPoolType: 'nodeIPConfiguration'
      }
      podCidr: '10.244.0.0/16' 
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      outboundType: 'loadBalancer'
      podCidrs: [
        '10.244.0.0/16'
      ]
      serviceCidrs: [
        '10.0.0.0/16'
      ]
      ipFamilies: [
        'IPv4'
      ]
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      'daemonset-eviction-for-empty-nodes': false
      'daemonset-eviction-for-occupied-nodes': true
      expander: 'random'
      'ignore-daemonsets-utilization': true
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '5m'
      'scale-down-delay-after-delete': '10s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '5m'
      'scale-down-unready-time': '5m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '30s'
      'skip-nodes-with-local-storage': 'false'
      'skip-nodes-with-system-pods': 'true'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    disableLocalAccounts: false
    identityProfile: { 
      kubeletIdentity: {
        resourceId: kubeletUserAssignedIdentity.id
        clientId: kubeletUserAssignedIdentity.properties.clientId
        objectId: kubeletUserAssignedIdentity.properties.principalId
      }
    }
    ingressProfile: {
      webAppRouting: { 
        // Use the AKS managed app routing (nginx ingress controller) in PROD only if not using private net. 
        // This allows IP based requests to show up in metrics (see issue here: https://github.com/Azure/AKS/issues/5216)
        enabled: enableAKSAppRoutingAddon 
      }
    }
    securityProfile: {
      imageCleaner: {
        enabled: true
        intervalHours: 168
      }
      workloadIdentity: {
        enabled: true
      }
    }
    storageProfile: {
      // Allow Disk or Azure files PV / PVC
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    workloadAutoScalerProfile: {
      keda: {
        // This Uses a custom KEDA in the workload not the addon due to dependency issues / managed identity
        enabled: false 
      }
    }
    metricsProfile: {
      costAnalysis: {
        enabled: false // enable for cost analysis recommended in prod only
      }
    }
  }
}

resource userPools 'Microsoft.ContainerService/managedClusters/agentPools@2025-07-02-preview' = [for n in nodePools : {
  parent: managedCluster
  name: n.name
  properties: {
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
    powerState: { 
      code: 'Running'
    }
    enableNodePublicIP: false
    nodeLabels: n.nodeLabels
    mode: 'User'
    osType: 'Linux'
    osSKU: 'AzureLinux'
    enableFIPS: false
    securityProfile: {
      enableVTPM: false
      enableSecureBoot: false
    }
    vnetSubnetID: enablePrivateNetwork ? privateVNetSubnetId : null
  }
}]

resource aksManagedAutoUpgradeSchedule 'Microsoft.ContainerService/managedClusters/maintenanceConfigurations@2025-07-02-preview' = {
  parent: managedCluster
  name: 'aksManagedAutoUpgradeSchedule'
  properties: {
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
}

resource aksManagedNodeOSUpgradeSchedule 'Microsoft.ContainerService/managedClusters/maintenanceConfigurations@2025-07-02-preview' = {
  parent: managedCluster
  name: 'aksManagedNodeOSUpgradeSchedule'
  properties: {
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
}

// Create federated identity needed for keda workload to access azure monitor
resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
    name: 'fed-${kedaUserAssignedIdentity.name}'
    parent: kedaUserAssignedIdentity
    properties: {
        issuer: managedCluster.properties.oidcIssuerProfile.issuerURL
        subject: 'system:serviceaccount:keda:keda-operator'
        audiences: [
            'api://AzureADTokenExchange'
        ]
    }
}

output aksUserAssignedIdentityName string = aksUserAssignedIdentity.name
output kubeletUserAssignedIdentityName string = kubeletUserAssignedIdentity.name
output kedaUserAssignedIdentityName string = kedaUserAssignedIdentity.name
output kedaUserAssignedIdentityClientId string = kedaUserAssignedIdentity.properties.clientId
output oidcIssuerProfileissuerUrl string = managedCluster.properties.oidcIssuerProfile.issuerURL
output kedaFederatedIdentityName string = 'fed-${kedaUserAssignedIdentity.name}'
