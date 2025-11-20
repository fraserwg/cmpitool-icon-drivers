#!/usr/bin/bash
#SBATCH --job-name=noncmore_preprocess_ICON-ESM-ER
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --mem=256G
#SBATCH --exclusive 
#SBATCH --time=08:00:00
#SBATCH --account=bm1344
#SBATCH --output=log/noncmore_preprocess_ICON-ESM-dragon.%j.out

# limit stacksize ... adjust to your programs need
# and core file size
ulimit -s 204800
ulimit -c 0

module load cdo
module load parallel

# USER OPTIONS
# Parallel processing options
export PROCS=8  # Number of openmp threads for cdo to use
export BATCH_SIZE=6  # Number of cdo jobs to run at a time
# hint: PROCS * BATCH_SIZE should be less than the number of processors on your machine.

# Model name options
export model_name="ICON-ESM-dragon-test"  # Human readable name of the model (used for output)
export exp_name="hel25213_r3b7-r2b9"  # exp_name (used for input)

# Input data options
export model_dir="/work/mh0033/m211054/projects/icon/dragon/feature-xpp-tuning/build_hdint_levante.intel/experiments/hel25213_r3b7-r2b9"
# directory models outputs can be found (may use 'glob' like syntax) e.g.:
# export model_dir="/work/bm1344/k203123/experiments/${exp_name}/run*" 

# File containing geometric height of the atmospheric grid (z_mc)
export atm_zg_file="/work/mh1494/m300466/icon-xpp/icon-2025.09.30/build_hdint_ghcpu/experiments/dragon_15nodes_oce200mpi_getvertgrid/dragon_15nodes_oce200mpi_getvertgrid_atm_vertgrid_19500101T000000Z.nc"


# Prefixes of the files containing different variables
# Filenames should have the format <<prefix>>YYYYMMDDTHHMMSSZ<<suffix>
# where YYYYMMDDTHHMMSSZ is a datestamp.
# All files should be output at a monthly frequency and contain only one months
# worth of averaged data.

export tas_prefix="${exp_name}_atm_2d_ml_"
export clt_prefix="${exp_name}_atm_2d_ml_"
export pr_prefix="${exp_name}_atm_2d_ml_"
export rlut_prefix="${exp_name}_atm_2d_ml_"
export uas_prefix="${exp_name}_atm_3d_ml_"
export vas_prefix="${exp_name}_atm_3d_ml_"

export ua300hPa_prefix="${exp_name}_atm_3d_ml_"
export zg500hPa_prefix="${exp_name}_atm_3d_ml_"

export siconc_prefix="${exp_name}_oce_qps_"
# export zos_prefix="ssh/${exp_name}_oce_ssh_"
export zos_prefix="${exp_name}_oce_kin_"
export tos_prefix="${exp_name}_oce_qps_"
export mlotst_prefix="${exp_name}_oce_qps_"

export to_prefix="${exp_name}_oce_qps_"
export so_prefix="${exp_name}_oce_qps_"

export icon_file_suffix=".nc"

# export first_year=1950
export first_year=1998
export last_year=1999

# Output data options
model_name_lower=$(echo "$model_name" | tr '[:upper:]' '[:lower:]')
# export model_name_lower
export outdir="/work/mh0256/m301014/cmpitool-icon-drivers/data/processed/${model_name_lower}"
export tmpdir="/work/mh0256/m301014/cmpitool-icon-drivers/data/temp/${model_name_lower}"

./_noncmore_preprocess_ICON-ESM-flexible.sh
