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

module storageAccountModule 'br/public:avm/res/storage/storage-account:0.29.0' = {
  name: 'storageAccount'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    kind: isPremiumTier ? 'FileStorage': 'StorageV2'  // PAYG files share for Standard tier
    skuName:storageAccountSku
    publicNetworkAccess: 'Enabled' // Not recommended for PROD use
    minimumTlsVersion: 'TLS1_2'
    largeFileSharesState: 'Enabled'
    accessTier: isPremiumTier ? null : 'Hot'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

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

module fileServicesShares 'br/public:avm/res/storage/storage-account/file-service/share:0.1.1' = [ for shareName in fileShareNames: {
  name: 'fileservices-${shareName}'
  params: {
    storageAccountName: storageAccountName
    name: shareName
    shareQuota: shareSizeGb
    enabledProtocols: 'SMB'
    accessTier: shareTier
  }
}]

