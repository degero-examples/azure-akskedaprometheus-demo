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

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: isPremiumTier ?{
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

// Create two file shares with different names for each app (one, two)
resource fileServicesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = [for shareName in fileShareNames: {
  parent: fileServices
  name: shareName
  properties: isPremiumTier ? {
    provisionedIops: 1205
    provisionedBandwidthMibps: 81
    shareQuota: shareSizeGb
    enabledProtocols: 'SMB'
  } : {
    shareQuota: shareSizeGb
    enabledProtocols: 'SMB'
    accessTier: shareTier
  }
}]
