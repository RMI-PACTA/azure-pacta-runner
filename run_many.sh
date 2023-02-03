az vm create \
    --resource-group MFM2022 \
    --name mrdc-runner-C- \
    --image UbuntuLTS \
    --assign-identity /subscriptions/feef729b-4584-44af-a0f9-4827075512f9/resourceGroups/UST-2022/providers/Microsoft.ManagedIdentity/userAssignedIdentities/PACTA-runner \
    --admin-username azureuser \
    --public-ip-address "" \
    --size "Standard_E4-2as_v4" \
    --count 5 \
    --custom-data cloud-init.txt

