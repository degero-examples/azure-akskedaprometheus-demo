#!/bin/bash
# Deploy Azure infrastructre via bicep and write outputs to ../scripts/.env.auzre to deploy workload to cluster

set -euo pipefail

# Prompt user for location and resource group name
read -r -p "Resource group location (e.g. eastus): " LOCATION
while [ -z "$LOCATION" ]; do
  echo "Resource group location is required."
  read -r -p "Resource group location (e.g. eastus): " LOCATION
done

read -r -p "Resource group name: " RESOURCE_GROUP
while [ -z "$RESOURCE_GROUP" ]; do
  echo "Resource group name is required."
  read -r -p "Resource group name: " RESOURCE_GROUP
done

echo "Creating resource group '$RESOURCE_GROUP' in location '$LOCATION'..."
az group create -l "$LOCATION" -n "$RESOURCE_GROUP"

# take outputs from below and write them to ../scripts/.env.azure
echo "Deploying bicep template..."
az deployment group create -g "$RESOURCE_GROUP" --template-file main.bicep --parameters default.bicepparam || { echo "Deployment failed."; exit 1; }

# Get all output names
output_names=$(az deployment group show \
  --resource-group rg-kedascalerapp-dev \
  --name main \
  --query 'properties.outputs | keys(@)' \
  -o tsv)

# Create the env file header
cat > ../scripts/.env.azure << 'EOF'
#!/bin/bash
# Auto-generated from Azure bicep deployment outputs

EOF

# Loop through each output and get its value
for output_name in $output_names; do
  output_value=$(az deployment group show \
    --resource-group rg-kedascalerapp-dev \
    --name main \
    --query "properties.outputs.$output_name.value" \
    -o tsv)
  
  # Write to file
  KEY=$(echo $output_name | sed 's/.*/\U&/')
  echo "$KEY=\"$output_value\"" >> ../scripts/.env.azure
  
done

echo "All environment variables written to ../scripts/.env.azure"
echo ""
echo "Run /scripts/deploy-azure-workload.sh to deploy the dependencies and worklaod to AKS"