# PACTA Runner on Azure VM

`run.sh` creates a VM, and uses `cloud-init` to prepare it as a PACTA runner.

This system is such that every machine is capable of cold-starting the entire process, so long as there is access to an Azure File Share (storage account) that contains PACTA directories.
