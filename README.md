# cmpitool-icon-drivers

This repository contains code used for preparing [ICON earth system model](https://www.icon-model.org) data for use with the [CMPITool](https://github.com/JanStreffing/cmpitool/tree/master). CMPITool is a tool used for evaluating the performance of climate models. It expects input data to be in a certain format which is different to the format raw dat from the ICON model is output. The scripts in this repository will process raw ICON outputs into the files required by CMPITool

## Useage
The `src` folder contains two files: `submit_ICON-ESM-ER_script.sh` (hereafter, the submission scripts) and `noncmore_preprocess_ICON-ESM-ER.sh` (hereafter, the processing script).

The submission script contains multiple environment variables that should be set by the user when processing model output. The script can be submitted to a SLURM queue using the `sbatch` command. To process 1 year of a 5 km ocean coupled to a 10 km atmosphere model takes around 15 minutes.

The user shouldn't need to make changes to the processing script if their data is output in a `normal' way.

When the scripts have run, the user should be able to use CMPITool as normal.