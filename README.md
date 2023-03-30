# PACTA Runner on Azure VMs

`run_many.sh` is a shell script that spins up many VMs, and uses `cloud-init` to prepare each of them as a PACTA runner.

This system is such that every machine is capable of cold-starting the entire process, so long as there is access to an Azure File Share (storage account) that contains PACTA directories.

## Setup the AFS

**DO ALL OF THIS IN `tmux`**

The first step to running this process is setting up the Azure File Share.
It is easiest to create the queue if all the data that you want to run PACTA on is structured as follows:

``` bash
investor_name
├── portfolio_name_1
│   ├── 00_Log_Files
│   ├── 10_Parameter_File
│   │   └── portfolio_name_1_PortfolioParameters.yml
│   ├── 20_Raw_Inputs
│   │   └── portfolio_name_1.csv
│   ├── 30_Processed_Inputs
│   ├── 40_Results
│   └── 50_Outputs
└── portfolio_name_2
    ├── 00_Log_Files
    ├── 10_Parameter_File
    │   └── portfolio_name_2_PortfolioParameters.yml
    ├── 20_Raw_Inputs
    │   └── portfolio_name_2.csv
    ├── 30_Processed_Inputs
    ├── 40_Results
    └── 50_Outputs
````
Note: `investor_name` and `portfolio_name` are just placeholders, they can be anything. You can have as many directories in the queue as you like, but it's good that they all have the same number of levels. 

* Once all your portfolios are prepared, upload them to the AFS (tarred). Use the following command to do this: `tar -zcvf archive-name.tar.gz source-directory-name`
* Note: It's important in the above command that `source_directory_name` specifies a single directories (not `path/to/directory`), otherwise the whole parent directory structure gets tarred. 
* Once the data is somewhere on the AFS (put it in a folder specific to the project), you must untar it with: `tar -xzvm --no-same-permissions --no-same-owner -f archive-name.tar.gz`
Note that using a `zip` file (rather than `.tar.gz`) is acceptable, but unzipping on AFS is a slow process, that throws a lot of uninformative warnings about permissions

## Setup the Analysis Details

The next step is to create a file called `workflow.meta.report.yml`, in the root of the directory you just created. 

* It should look something like:
``` yml
default:
  run_results: true # (run `web_tool_scripts_1.R` and `_2.R`)
  run_reports: false # (do you want reports to be generated)
  docker_tag: "0.0.0.9055" (what docker tag of rmi_pacta should be used, it MUST be on the registry)
  docker_image: "transitionmonitordockerregistry.azurecr.io/rmi_pacta" (image to use, must be on TM registry otherwise runners won't see it)
```

## Create the queue

The next step is to create a queue file. This file keeps track of a few things, such as the paths of all the portfolios you want to run, the status of that portfolio (has it been run or not?), the value of `portfolio_name_ref_all`, and the time that the queue value was created or updated. 

VM runners will check this queue to determine the next portfolio to be run (and update this queue once a portfolio has finished running).

To create the queue is still a very manual process, as it can be finicky. To do this:
* Hop onto a VM that has access to the AFS (right now we have only one long-lived VM)
* Navigate to the project directory on the AFS. This is very important, you must be in the directory that has `workflow.meta.report.yml` at it's root, as well as a single top-level directory containing all the sub-directories of portoflios you would like to run.
* Make sure `workflow.meta.report.data.creator` is cloned in `~/`, and up-to-date with `main`
* Open up an R session on the VM
* source("~/workflow.meta.report.data.creator/R/manage_queue.R")
* Type the following in R:
``` r
library(txtq)
queue <- txtq("queue")
```
* Note: The argument "queue" of the function `txtq()` in the code above is a path to a soon-to-be created directory, called "queue". This means it will get created relative to wherever you opened the R session. The "queue" directory should be in the same directory as the `workflow.meta.report.data.creator.yml` file
* Now we need to populate this queue file with the paths to every portfolio you want to run
* Call something like `list.files("/path/to/your/pacta/inputs", recursive = FALSE, recursive = FALSE, full.names = TRUE)`
* You want to end up with some object, e.g. `queue_relpaths`, with the following contents: 
``` r
[R] > queue_relpaths
[1] "pacta_inputs/meta_portfolio/meta_portfolio"
[2] "pacta_inputs/peer_level/pension_fund"
[3] "pacta_inputs/peer_level/asset_manager"
[4] "pacta_inputs/peer_level/bank"
```

where the next level down would be the `00_Log_Files`, `10_Processed_Inputs`, etc.

* Type `prepare_queue_message(relpath = queue_relpaths, status = "waiting", portfolio_name_ref_all = basename(queue_relpaths))`
* Pipe the above into `%>% queue$push(message = ., title = "Project Name")` (this will write the queue to the queue directory)
* Now you can inspect the `queue` object with commands like: 
* `queue$count()` - To see the number of portfolios left in the queue. This number will go down once the runners start running PACTA
* queue$list() - This is a more verbose list of all of the portfolios left to run

## Prepare `run_many.sh`

Now you are more or less ready to get things going. You can detach from your tmux session on the VM, and go back to your local computer. 

* Make sure you have this repo cloned locally (`azure-pacta-runner`)
* Open up the file `run_many.sh` in a text editor, and edit the `count` field with the number of VMs you want to spin up (we can use up to ~200), they each cost 0.25 Euro/ hour (or part thereof, e.g. 63min = 2 hours)
* Edit the `resource-group` to a name to track costs of running. NOTE THIS DOES NOT CREATE THE RESOURCE GROUP. It must be already created on azure. Check the azure portal to see what resource groups already exist

## Prepare `cloud_init.txt`

Now open up the `cloud_init.txt` file. This is the file that will be used to create each VM (including installing all of it's dependencies etc.)

* Ensure that line 68 points to wherever your `workflow.meta.report.yml` is, in relation to `/mnt/dataprep2021q4/rawdata`
  * Note that the runners mount the `rawdata` fileshare at `/mnt/dataprep2021q4/rawdata`, which is different than where dataprep-bigmem mounts it (`/mnt/rawdata`)

## Run the VMs

You will first need to make sure you are authenticated with Azure. This should happen automatically if you are working from an RMI computer:

* `az identity list`
  * if you are not logged in, you may need to run `az login`

Once that runs, you can spin up your runners (finally, woo!):
* `./run_many.sh`

## Inspect status of the VMs

 The easiest way to inspect your VMs is on the portal. However, here you will only know if they are running or not, you will not be able to tell if they are actually running portfolios.

* Check out portal.azure.com virtual machines
* There should be ones created called `mrdc-runner-C` with all of the VMs that you created
  * Note: mrdc = Meta Report Data Creator
* Pro-tip: A machine that is running is running

To actually see how the machines are progressing against the portfolios, you can inspect a file called `supplemental`, in the `queue` folder.

* The command `tail -f queue/supplemental` will give a live feed of processes as they are happening in the queue

## Clean-up

When everything is done running, you need to make sure to actually turn off all of the VMs. To do this:

* Open the Azure portal
* Go to the resource group you had set for the process
* Filter for mrdc
* Click the little three dots, then click delete (and say that you are sure)
  * You can force-delete the machines (rather than waiting for Azure to send a kill signal to them and then waiting for them to shutdown cleanly)
