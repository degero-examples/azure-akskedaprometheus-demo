@maxLength(24)
param storageAccountName string
param fileShareNames array
param tags object
@description('Quota in GB for the file share, default is 1GB')
param shareSizeGb int
param shareTier string = 'Hot'
param deletedFileRetentionDays int = 0
param storageAccountSku string = 'Standard_LRS'

var location = resourceGroup().location
var isPremiumTier = contains(storageAccountSku, 'Premium') 

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  kind: isPremiumTier ? 'FileStorage': 'StorageV2'  // PAYG files share for Standard tier
  sku: {
    name: storageAccountSku
  }
  properties: union({
      publicNetworkAccess: 'Enabled' // Not recommended for PROD use
      minimumTlsVersion: 'TLS1_2'
      largeFileSharesState: 'Enabled'
    }, isPremiumTier ? {} : {
    accessTier: 'Hot'
  })
  tags: tags
}

// module storageAccountModule 'br/public:avm/res/storage/storage-account:0.29.0' = {
//   name: 'storage-avm'
//   params: {
//     name: storageAccountName
//     location: location
//     tags: tags
//     kind: isPremiumTier ? 'FileStorage': 'StorageV2'  // PAYG files share for Standard tier
//     skuName: storageAccountSku
//     publicNetworkAccess: 'Enabled' // Not recommended for PROD use
//     minimumTlsVersion: 'TLS1_2'
//     largeFileSharesState: 'Enabled'
//     accessTier: isPremiumTier ? null : 'Hot'
//   }
// }

// resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
//   dependsOn:[storageAccountModule]
//   name: storageAccountName
// }

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: isPremiumTier ? {
        multichannel: {
          enabled: false
        }
      } : {}
    }
    cors: {
      corsRules: []
    }
    shareDeleteRetentionPolicy: (deletedFileRetentionDays > 0) ? {
      enabled: true
      days: deletedFileRetentionDays
    } : {}
  }
}


// #########
// TODO use AVM when default accesstier issue resolved: https://github.com/Azure/bicep-registry-modules/issues/6092

// This is painful duplication as bicep syntax requires params as object literal and accessTier can only be defined for non premium
// setting accesstier: null will fail
// module fileServicesSharesPremium 'br/public:avm/res/storage/storage-account/file-service/share:0.1.1' = [for (shareName, i) in fileShareNames: if (isPremiumTier == true) {
//   dependsOn: [storageAccountModule, fileServices]
//   name: 'fileservices-avm-${shareName}'
//   params: {
//     storageAccountName: storageAccountName
//     name: shareName
//     shareQuota: shareSizeGb
//     enabledProtocols: 'SMB'
//   }
// }]

// module fileServicesSharesRegular 'br/public:avm/res/storage/storage-account/file-service/share:0.1.1' = [for (shareName, i) in fileShareNames: if (isPremiumTier == false) {
//   dependsOn: [storageAccountModule, fileServices]
//   name: 'fileservices-avm-${shareName}'
//   params: {
//     storageAccountName: storageAccountName
//     name: shareName
//     shareQuota: shareSizeGb
//     enabledProtocols: 'SMB'
//     accessTier: shareTier 
//   }
// }]

// TODO remove below once above issue fixed in AVM
// Create two file shares with different names for each app (one, two)
resource fileServicesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = [for shareName in fileShareNames: {
  parent: fileServices
  name: shareName
  properties: isPremiumTier ? {
    provisionedIops: 4024
    provisionedBandwidthMibps: 228
    shareQuota: shareSizeGb
    enabledProtocols: 'SMB'
  } : {
    shareQuota: shareSizeGb
    enabledProtocols: 'SMB'
    accessTier: shareTier
  }
}]
