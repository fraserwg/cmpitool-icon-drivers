# cmpitool-icon-drivers
This repository contains code used for preparing [ICON earth system model](https://www.icon-model.org) data for use with the [CMPITool](https://github.com/JanStreffing/cmpitool/tree/master). CMPITool is a tool used for evaluating the performance of climate models. It expects input data to be in a certain format which is different to the format raw dat from the ICON model is output. The scripts in this repository will process raw ICON outputs into the files required by CMPITool

## Use with the dragon run
In the `src` folder you will `submit_ICON-ESM-dragon_script.sh` (hereafter, the submission script). This SLURM script can be used to run the script `noncmore_preprocess_ICON-ESM-dragon.sh` (hereafter, the processing script).

In the submission script, you should update the SLURM account.

You should point the script to your model data by setting the variables `exp_name` and `model_dir`. You may set the variable `model_name` to anything you wish as this is used for naming the regridded output files.

The script expect the outputs to be structured in the same way as those in `hel25213_r3b7-r2b9`.

You should run the submission script using `sbatch submit_ICON-ESM-dragon_script.sh`. The script will create temporary files saved in `data/temp/${model_name}`. These files are then further processed into the files needed by CMIPTool and saved in `data/processed/${model_name}`.

Having produced the scripts, you may then run the notebook `apply-CMPITool.ipynb` which is stored in the `src` directory. You should run it in a python environment which has CMPITool instaled. You should set the variable `model_name` to match that used in the submission script. You also need to update the start of the `path_to_model` variable to point to *your* version of this repository.

For questions about the running of `apply-CMPITool.ipynb` consult the [CMPITool documentation](https://cmpitool.readthedocs.io/en/latest/).

## Useage
The `src` folder contains two files: `submit_ICON-ESM-ER_script.sh` (hereafter, the submission scripts) and `noncmore_preprocess_ICON-ESM-ER.sh` (hereafter, the processing script).

The submission script contains multiple environment variables that should be set by the user when processing model output. The script can be submitted to a SLURM queue using the `sbatch` command. To process 1 year of a 5 km ocean coupled to a 10 km atmosphere model takes around 15 minutes.

The user shouldn't need to make changes to the processing script if their data is output in a `normal' way.

When the scripts have run, the user should be able to use CMPITool as normal.