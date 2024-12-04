#!/usr/bin/bash
#SBATCH --job-name=noncmore_preprocess_ICON-ESM-ER
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --mem=256G
#SBATCH --exclusive 
#SBATCH --time=06:00:00
#SBATCH --account=bk1377
#SBATCH --output=noncmore_preprocess_ICON-ESM-ER.%j.out

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

# Input data options
export model_dir="/work/bm1344/k203123/experiments/erc2002/run*"  # directory models outputs can be found (may use 'glob' like syntax)

export atm_zg_file="/work/mh0033/m300029/GIT/R2B8_0033_atm_zg_zghalf.nc"  # File containing geometric height of the atmospheric grid (zg)

# Prefixes of the files containing different variables
# Filenames should have the format <<prefix>>YYYYMMDDTHHMMSSZ<<suffix>
# where YYYYMMDDTHHMMSSZ is a datestamp.
# All files should be output at a monthly frequency and contain only one months
# worth of averaged data.
export oce_ml_prefix="erc2002_oce_ml_1mth_mean_"  # Should contain to and so at all model levels
export oce_2d_prefix="erc2002_oce_2d_1mth_mean_"  # Should contain conc, mlotst10, to and ssh on surface model level
export atm_ml_prefix="erc2002_atm_ml_1mth_mean_"  # Should contain ua, pfull
export atm_2d_prefix="erc2002_atm_2d_1mth_mean_"  # Should contain ps, tas, pr, rlut, uas, vas, clt
export icon_file_suffix=".nc"

export first_year=1991
export last_year=1991

# Output data options
export model_name="ICON-ESM-ER"
export outdir="/work/mh0256/m301014/cmpitool/data/postprocessing/icon-esm-er-time"
export tmpdir="/work/mh0256/m301014/cmpitool/data/temp/icon-esm-er-time"

./noncmore_preprocess_ICON-ESM-ER.sh
