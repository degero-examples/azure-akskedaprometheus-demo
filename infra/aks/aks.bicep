param clustername string
param tags object
param logWorkspaceName string
param clusterSKU string
param nodePools array
param agentPoolMaxCount int
param agentPoolVMSize string
param enablePrivateNetwork bool
param privateVNetSubnetId string
param enableAKSAppRoutingAddon bool 

var location string = resourceGroup().location

// AKS cluster User assigned identity cant use AVM due to bicep depencency syntax issue
resource aksUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: 'mi-${clustername}'
  location: location
  tags: tags
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
    clusterIdentityName: aksUserAssignedIdentity.name
    kubeletIdentityName: kubeletUserAssignedIdentity.outputs.name
  }
}

var logworkspaceId = resourceId(resourceGroup().name, 'Microsoft.OperationalInsights/workspaces', logWorkspaceName)

// Bug with AVM and vnet not in MC rg, using regular resource.
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
        resourceId: kubeletUserAssignedIdentity.outputs.resourceId
        clientId: kubeletUserAssignedIdentity.outputs.clientId
        objectId: kubeletUserAssignedIdentity.outputs.principalId
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

resource kedaIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  dependsOn: [ kedaUserAssignedIdentity ]
  name: 'mi-keda-${clustername}'
}

// Create federated identity needed for keda workload to access azure monitor
resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
    name: 'fed-${kedaUserAssignedIdentity.name}'
    parent: kedaIdentity
    properties: {
        issuer: managedCluster.properties.oidcIssuerProfile.issuerURL!
        subject: 'system:serviceaccount:keda:keda-operator'
        audiences: [
            'api://AzureADTokenExchange'
        ]
    }
}

output aksUserAssignedIdentityName string = aksUserAssignedIdentity.name
output kubeletUserAssignedIdentityName string = kubeletUserAssignedIdentity.outputs.name
output kedaUserAssignedIdentityName string = kedaUserAssignedIdentity.outputs.name
output kedaUserAssignedIdentityClientId string = kedaUserAssignedIdentity.outputs.clientId
output oidcIssuerProfileissuerUrl string = managedCluster.properties.oidcIssuerProfile.issuerURL!
output kedaFederatedIdentityName string = 'fed-${kedaUserAssignedIdentity.outputs.name}'
