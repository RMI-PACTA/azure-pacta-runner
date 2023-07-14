SUBNETID=$(az network vnet subnet show --resource-group RMI-PROD-EU-VNET-RG --name Server --vnet-name RMI-PROD-EU-VNET --query id -o tsv)

az vm create \
    --resource-group UST-2022 \
    --name pacta-runner-ssh \
    --image UbuntuLTS \
    --assign-identity /subscriptions/feef729b-4584-44af-a0f9-4827075512f9/resourceGroups/UST-2022/providers/Microsoft.ManagedIdentity/userAssignedIdentities/PACTA-runner \
    --admin-username azureuser \
    --subnet $SUBNETID \
    --public-ip-address "" \
    --size "Standard_E4-2as_v4" \
    --generate-ssh-keys \
    --custom-data cloud-init.txt

