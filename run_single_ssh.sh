az vm create \
    --resource-group UST-2022 \
    --name pacta-runner-ssh \
    --image UbuntuLTS \
    --assign-identity /subscriptions/feef729b-4584-44af-a0f9-4827075512f9/resourceGroups/UST-2022/providers/Microsoft.ManagedIdentity/userAssignedIdentities/PACTA-runner \
    --admin-username azureuser \
    --public-ip-address UST03-ip \
    --public-ip-sku Basic \
    --ssh-key-name UST-VM-key \
    --size "Standard_E4-2as_v4" \
    --custom-data cloud-init.txt

