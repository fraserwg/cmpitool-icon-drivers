#!/usr/bin/bash

Help()
{
   # Display Help
	echo "###############################################################################"
	echo "# This script will prepare raw ICON outputs for use with the CMPITool         #"
	echo "# Author:     Fraser Goldsworth (04-12-2024)		                            #"
	echo "###############################################################################"
	echo "# The following environment variables must be set for the script to run       #"
    echo "#     Parallel processing options                                             #"
	echo "#         PROCS       : Number of openmp threads for cdo to use               #"
	echo "#         BATCH_SIZE  : Number of cdo jobs to run at a time                   #"
    echo "#                                                                             #"
    echo "#     Input data options                                                      #"
    echo "#         model_dir       : Directory models outputs can be found (may use    #"
    echo "#                             'glob' like syntax)                             #"
    echo "#         atm_zg_file     : File containing time-independent geometric height #"
    echo "#                             of the atmospheric grid (zg)                    #"
    echo "#         oce_ml_prefix   : Should contain to and so at all model levels      #"
    echo "#         oce_2d_prefix   : Should contain conc, mlotst10, to and ssh on      #"
    echo "#                             surface model level                             #"
    echo "#         atm_ml_prefix   : Should contain u, v, pres at all model levels     #"
    echo "#         atm_2d_prefix   : Should contain pres_sfc, tas, pr, thb_t, clt      #"
    echo "#                             as 2D variables                                 #"
    echo "#         icon_file_suffix: Suffix of raw output files, e.g. '.nc'            #"
    echo "#         first_year      : First year of analysis                            #"
    echo "#         last_year      : Last year of analysis                              #"
    echo "#                                                                             #"
    echo "#     Output data options                                                     #"
    echo "#         model_name  : Name of model for CMPITool                            #"
    echo "#         outdir      : Directory to store CMPITool formatted outputs         #"
    echo "#         tmpdir      : Directory to store temporary outputs                  #"
	echo "###############################################################################"
    echo "# Note on input data options:                                                 #"
    echo "#     Filenames of data files are contsturctured from the 'prefix' options    #"
    echo "#         and should have format '<<prefix>>YYMMDDTHHMMSSZ<<suffix>>' where   #"
    echo "#         YYYYMMDDTHHMMSSZ is a datestamp. All files should be output at a    #"
    echo "#         monthly frequency and contain monthly averaged data.                #"
	echo "###############################################################################"

}
Help

# Create the tempdir and outdir folders if needed.
if [ ! -d ${outdir} ]
then
  mkdir -p ${outdir}
fi
if [ ! -d ${tmpdir} ]
then
  mkdir -p ${tmpdir}
fi

# Below we define a function that checks for the existence of files and removes
# and removes them if they are corrupted.
check_for_and_remove_incomplete_files() {
    file=$1
    echo "Checking for existence of: ${file}"
    if [ -e "${file}" ];
    then
        echo "  file exists"
        file_size=$(stat -c%s "${file}")
        if [ "$file_size" -lt $((50 * 1024)) ];
        then
            echo "  file size is smaller than expected"
            echo "  file removed"
            rm "${file}"
        fi
    else
        echo "  file does not yet exist"
    fi
}
export -f check_for_and_remove_incomplete_files

printf "##################################\n"
printf "# Construct the data paths       #\n"
printf "##################################\n"
echo "Will search the folder ${model_dir} for raw outputs"
OCE_ML_FILES=()  # formerly ML_FILES
OCE_2D_FILES=()  # formerly OCE_TWOD_FILES
ATM_2D_FILES=()
ATM_ML_FILES=()

DATE_STAMPS=()
for YEAR in $(seq ${first_year} ${last_year});
do
    for MONTH in {01..12};
    do
        DATE_STAMPS+=( "${YEAR}${MONTH}??T??????Z" )
    done
done
# Add an extra element at the end
last_year_p1=$((last_year + 1))
DATE_STAMPS+=( "${last_year_p1}01??T??????Z" )

# Create temporary files to hold results
OCE_ML_TEMP=$(mktemp)
OCE_2D_TEMP=$(mktemp)
ATM_ML_TEMP=$(mktemp)
ATM_2D_TEMP=$(mktemp)

# Remove the first element and loop to find the files
for date_stamp in "${DATE_STAMPS[@]:1}"; do
    echo "Searching for files with datestamp pattern: ${date_stamp}"

    # Run find commands concurrently, outputting to temporary files
    {
        find ${model_dir}/${oce_ml_prefix}${date_stamp}${icon_file_suffix} ! -name "*.bck*" >> "$OCE_ML_TEMP"
    } &

    {
        find ${model_dir}/${oce_2d_prefix}${date_stamp}${icon_file_suffix} ! -name "*.bck*" >> "$OCE_2D_TEMP"
    } &

    {
        find ${model_dir}/${atm_ml_prefix}${date_stamp}${icon_file_suffix} ! -name "*.bck*" >> "$ATM_ML_TEMP"
    } &

    {
        find ${model_dir}/${atm_2d_prefix}${date_stamp}${icon_file_suffix} ! -name "*.bck*" >> "$ATM_2D_TEMP"
    } &

    # Wait for all background processes to complete
    wait
done
# Read results from temporary files back into arrays
mapfile -t OCE_ML_FILES < "$OCE_ML_TEMP"
mapfile -t OCE_2D_FILES < "$OCE_2D_TEMP"
mapfile -t ATM_ML_FILES < "$ATM_ML_TEMP"
mapfile -t ATM_2D_FILES < "$ATM_2D_TEMP"

rm "$OCE_ML_TEMP" "$OCE_2D_TEMP" "$ATM_ML_TEMP" "$ATM_2D_TEMP"

# for date_stamp in "${DATE_STAMPS[@]:1}";
# do
#     echo "Searching for files with datestamp pattern: ${date_stamp}"
#     OCE_ML_FILES+=( $(find ${model_dir}/${oce_ml_prefix}${date_stamp}${icon_file_suffix}) )
#     OCE_2D_FILES+=( $(find ${model_dir}/${oce_2d_prefix}${date_stamp}${icon_file_suffix}) )
#     ATM_ML_FILES+=( $(find ${model_dir}/${atm_ml_prefix}${date_stamp}${icon_file_suffix}) )
#     ATM_2D_FILES+=( $(find ${model_dir}/${atm_2d_prefix}${date_stamp}${icon_file_suffix}) )
#     wait
# done

printf "##################################\n"
printf "# Operate on atm 2D data         #\n"
printf "##################################\n"

echo "Constructing interpolation weights for 2D atmospheric variables"
export ATM_2D_WGHTS="${tmpdir}/ATM_2D_weights.nc"

echo "Weights will be saved to: ${ATM_2D_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -selvar,t_s "${ATM_2D_FILES[0]}" "${ATM_2D_WGHTS}"

# Define the function to process individual atm_2d_files
atm_2d_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"

    echo ""
    echo "Remapping: tas"
    out_file="${tmpdir}/tas.gr2.${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -chname,t_s,tas -selvar,t_s "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi

    echo ""
    echo "Remapping: pr"
    out_file="${tmpdir}/pr.gr2.${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -chname,tot_prec_rate,pr -selvar,tot_prec_rate "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi

    echo ""
    echo "Remapping: rlut"
    out_file="${tmpdir}/rlut.gr2.${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -chname,thb_t,rlut -selvar,thb_t "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi

    echo ""
    echo "Remapping: clt"
    out_file="${tmpdir}/clt.gr2.${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -chname,clct,clt -selvar,"clct" "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi
}
export -f atm_2d_processing

echo "Processing individual 2D atmospheric variable files"
parallel --jobs $BATCH_SIZE "atm_2d_processing {}" ::: "${ATM_2D_FILES[@]}"

echo ""
echo "Merging remapped 2D atmospheric data into CMPITool formatted files"
for var in tas pr clt;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -yseasmean -shifttime,-1seconds -mergetime "${tmpdir}/${var}.gr2.*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"
done

for var in rlut;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -mulc,-1 -yseasmean -shifttime,-1seconds -mergetime "${tmpdir}/${var}.gr2.*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"
done





printf "##################################\n"
printf "# Operate on atm ML data         #\n"
printf "##################################\n"

atm_ml_processing() {
    in_file=$1
    sister_file="${in_file/_atm_3d_ml_/_atm_2d_ml_}"  # Create the sister file by replacing _atm_3d_ml_ with _atm_2d_ml_ in the filename
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on ${in_file}"

    echo ""
    echo "Remapping: ua (300 hPa)"
    ua300_out="${tmpdir}/ua.gr2.${filename}"
    check_for_and_remove_incomplete_files "${ua300_out}"
    if [ ! -e "${ua300_out}" ];
    then
        echo "Remapped output will be saved to: ${ua300_out}"
        cdo -P ${PROCS} -chname,u,ua -remap,r180x91,"${ATM_2D_WGHTS}" -ap2pl,30000 -merge -selvar,u,pres "${in_file}" -selvar,pres_sfc "${sister_file}" "${ua300_out}"
    else
        echo "  skipping remapping"
    fi
    
    # echo ""
    # echo "Remapping: zg (500 hPa)"
    # zg500_out="${tmpdir}/zg.gr2.${filename}"
    # check_for_and_remove_incomplete_files "${zg500_out}"
    # if [ ! -e "${zg500_out}" ];
    # then
    #     echo "Remapped output will be saved to: ${zg500_out}"
    #     # The setmisstoc part here shouldn't strictly be there; however, without it 
    #     # the remap weights have to be recomputed for every timestep...
    #     cdo -P "${PROCS}" -remap,r180x91,"${ATM_2D_WGHTS}" -setmisstoc,5500 -selvar,zg -ap2pl,50000 -merge -selvar,zg "${atm_zg_file}" -merge [ -selvar,pres "${in_file}" -selvar,pres_sfc "${sister_file}" ] "${zg500_out}"
    # else
    #     echo "  skipping remapping"
    # fi

    for var in u v ;
    do
        echo ""
        echo "Remapping: ${var}"
        out_file="${tmpdir}/${var}as.gr2.${filename}"
        check_for_and_remove_incomplete_files "${out_file}"
        if [ ! -e "${out_file}" ];
        then
            echo "Remapped output will be saved to: ${out_file}"
            cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -sellevel,89 -chname,"${var}","${var}as" -selvar,"${var}" "${in_file}" "${out_file}"
        else
            echo "  skipping remapping"
        fi
    done
}
export -f atm_ml_processing

echo "Processing individual ML atmospheric variable files"
parallel --jobs $BATCH_SIZE "atm_ml_processing {}" ::: "${ATM_ML_FILES[@]}"

echo ""
echo "Merging remapped ML atmospheric data into CMPITool formatted files"
echo "Files being saved into: ${outdir}/ua_${model_name}_${first_year}01-${last_year}12_300hPa_<<season>>.nc"
cdo -O -P ${PROCS} -splitseas -yseasmean -shifttime,-1seconds -mergetime "${tmpdir}/ua.gr2.*.nc" "${outdir}/ua_${model_name}_${first_year}01-${last_year}12_300hPa_"

echo "Files being saved into: ${outdir}/zg_${model_name}_${first_year}01-${last_year}12_500hPa_<<season>>.nc"
cdo -O -P ${PROCS} -splitseas -yseasmean -shifttime,-1seconds -mergetime "${tmpdir}/zg.gr2.*.nc" "${outdir}/zg_${model_name}_${first_year}01-${last_year}12_500hPa_"

for var in uas vas;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -yseasmean -shifttime,-1seconds -mergetime "${tmpdir}/${var}.gr2.*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"
done


printf "##################################\n"
printf "# Operate on oce ML data         #\n"
printf "##################################\n"

echo "Constructing interpolation weights for ML oceanic variables"
export OCE_ML_WGHTS="${tmpdir}/ML_weights.nc"

echo "Weights will be saved to: ${OCE_ML_WGHTS}"
cdo -P ${PROCS} -gencon,r180x91 -intlevel,10,100,1000,4000 -setctomiss,0 -selvar,to "${OCE_ML_FILES[0]}" "${OCE_ML_WGHTS}"


oce_ml_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on ${filename}"

    echo ""
    echo "Remapping: thetao"
    thetao_out="${tmpdir}/thetao.gr2.${filename}"
    check_for_and_remove_incomplete_files "${thetao_out}"
    if [ ! -e "${thetao_out}" ];
    then
        echo "Remapped output will be saved to: ${thetao_out}"
        cdo -P ${PROCS} -remap,r180x91,"${OCE_ML_WGHTS}" -intlevel,10,100,1000,4000 -setctomiss,0 -chname,to,thetao -selvar,to "${in_file}" "${thetao_out}"
    else
        echo "  skipping remapping"
    fi

    echo ""
    echo "Remapping: so"
    so_out="${tmpdir}/so.gr2.${filename}"
    check_for_and_remove_incomplete_files "${so_out}"
    if [ ! -e "${so_out}" ];
    then
        echo "Remapped output will be saved to: ${so_out}"
        cdo -P ${PROCS} -remap,r180x91,"${OCE_ML_WGHTS}" -intlevel,10,100,1000,4000 -setctomiss,0 -selvar,so "${in_file}" "${so_out}"
    else
        echo "  skipping remapping"
    fi

}

echo "Processing individual ML oceanic variable files"
export -f oce_ml_processing
parallel --jobs $BATCH_SIZE "oce_ml_processing {}" ::: "${OCE_ML_FILES[@]}"

echo ""
echo "Merging remapped ML oceanic data into CMPITool formatted files"
for var in thetao so;
do
    cdo -O -P ${PROCS} -mergetime "${tmpdir}/${var}.gr2.*.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12.nc"
    cdo -O -P ${PROCS} -splitlevel "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_000010.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_10m.nc"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_000100.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_100m.nc"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_001000.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_1000m.nc"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_004000.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_4000m.nc"

    for level in 10 100 1000 4000;
    do
        echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_${level}m_<<season>>.nc"
        cdo -O -P ${PROCS} -splitseas -yseasmean -shifttime,-1seconds "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_${level}m.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_${level}m_"
    done
done


printf "##################################\n"
printf "# Operate on oce 2D data         #\n"
printf "##################################\n"

echo "Constructing interpolation weights for 2D oceanic variables"

export OCE_2D_WGHTS="${tmpdir}/OCE_2D_weights.nc"
echo "Standard weights will be saved to: ${OCE_2D_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -setctomiss,0 -selvar,to "${OCE_2D_FILES[0]}" "${OCE_2D_WGHTS}"

# SI_WGHTS are used for sea ice and mixed layer depth.
export SI_WGHTS="${tmpdir}/SI_weights.nc"
echo "Sea ice weights will be saved to: ${SI_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -selvar,conc "${OCE_2D_FILES[0]}" "${SI_WGHTS}"

export ZOS_WGHTS="${tmpdir}/ZOS_weights.nc"
echo "ssh weights will be saved to: ${ZOS_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -setctomiss,0 -selvar,zos "${OCE_2D_FILES[0]}" "${ZOS_WGHTS}"


oce_2d_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"
    
    echo ""
    echo "Remapping: siconc"
    siconc_out="${tmpdir}/siconc.gr2.${filename}"
    check_for_and_remove_incomplete_files "${siconc_out}"
    if [ ! -e "${siconc_out}" ];
    then
        echo "Remapped output will be saved to: ${siconc_out}"
        cdo -P ${PROCS} -mulc,100 -remap,r180x91,"${SI_WGHTS}" -chname,conc,siconc -selvar,conc "${in_file}" "${siconc_out}"
    else
        echo "  skipping remapping"
    fi
    
    echo ""
    echo "Remapping: mlotst"
    mlotst_out="${tmpdir}/mlotst.gr2.${filename}"
    check_for_and_remove_incomplete_files "${mlotst_out}"
    if [ ! -e "${mlotst_out}" ];
    then
        echo "Remapped output will be saved to: ${mlotst_out}"
        cdo -P ${PROCS} -remap,r180x91,"${SI_WGHTS}" -selvar,mlotst "${in_file}" "${mlotst_out}"
    else
        echo "  skipping remapping"
    fi

    echo ""
    echo "Remapping: tos"
    tos_out="${tmpdir}/tos.gr2.${filename}"
    check_for_and_remove_incomplete_files "${tos_out}"
    if [ ! -e "${tos_out}" ];
    then
        echo "Remapped output will be saved to: ${tos_out}"
        cdo -P ${PROCS} -remap,r180x91,"${OCE_2D_WGHTS}" -setctomiss,0 -chname,to,tos -sellevel,1 -selvar,to "${in_file}" "${tos_out}"
    else
        echo "  skipping remapping"
    fi

    echo ""
    echo "Remapping: zos"
    zos_out="${tmpdir}/zos.gr2.${filename}"
    check_for_and_remove_incomplete_files "${zos_out}"
    if [ ! -e "${zos_out}" ];
    then
        echo "Remapped output will be saved to: ${zos_out}"
        cdo -P ${PROCS} -remap,r180x91,"${ZOS_WGHTS}" -setctomiss,0 -selvar,zos "${in_file}" "${zos_out}"
    else
        echo "  skipping remapping"
    fi
}

export -f oce_2d_processing
echo "Processing individual 2D oceanic variable files"
parallel --jobs $BATCH_SIZE "oce_2d_processing {}" ::: "${OCE_2D_FILES[@]}"


echo ""
echo "Merging remapped 2D oceanic data into CMPITool formatted files"
for var in siconc mlotst;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -yseasmean  -shifttime,-1seconds -mergetime "${tmpdir}/${var}.gr2.*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"
done

# Separate from above as we calculate the std for these variables.
for var in zos tos ;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -yseasstd  -shifttime,-1seconds -mergetime "${tmpdir}/${var}.gr2.*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"
done

echo ""
echo "Processing complete"
echo "CMPITool ready files have been saved in: ${outdir} "
echo "Temporary files have been saved in: ${tmpdir}"
echo "If you are satisfied the processing is complete you may clean-up any     "
echo "temporary files by running 'rm -r ${tmpdir}'"
echo ""
