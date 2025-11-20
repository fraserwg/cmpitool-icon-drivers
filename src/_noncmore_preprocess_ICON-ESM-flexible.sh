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
    echo "#                             of the atmospheric grid (z_mc)                    #"
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

echo "##################################\n"
echo "# Construct the data paths       #\n"
echo "##################################\n"
echo "Will search the folder ${model_dir} for raw outputs"
TAS_FILES=()
CLT_FILES=()
PR_FILES=()
RLUT_FILES=()
UAS_FILES=()
VAS_FILES=()
UA300HPA_FILES=()
ZG500HPA_FILES=()
SICONC_FILES=()
ZOS_FILES=()
TOS_FILES=()
MLOTST_FILES=()
TO_FILES=()
SO_FILES=()

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
TAS_TEMP=$(mktemp)
CLT_TEMP=$(mktemp)
PR_TEMP=$(mktemp)
RLUT_TEMP=$(mktemp)
UAS_TEMP=$(mktemp)
VAS_TEMP=$(mktemp)
UA300HPA_TEMP=$(mktemp)
ZG500HPA_TEMP=$(mktemp)
SICONC_TEMP=$(mktemp)
ZOS_TEMP=$(mktemp)
TOS_TEMP=$(mktemp)
MLOTST_TEMP=$(mktemp)
TO_TEMP=$(mktemp)
SO_TEMP=$(mktemp)

TEMPFILES=($TAS_TEMP $CLT_TEMP $PR_TEMP $RLUT_TEMP $UAS_TEMP $VAS_TEMP \
               $UA300HPA_TEMP $ZG500HPA_TEMP \
               $SICONC_TEMP $ZOS_TEMP $TOS_TEMP $MLOTST_TEMP \
               $TO_TEMP $SO_TEMP)

PREFIXFILES=($tas_prefix $clt_prefix $pr_prefix $rlut_prefix $uas_prefix $vas_prefix \
               $ua300hPa_prefix $zg500hPa_prefix \
               $siconc_prefix $zos_prefix $tos_prefix $mlotst_prefix \
               $to_prefix $so_prefix)

# Remove the first element and loop to find the files
for date_stamp in "${DATE_STAMPS[@]:1}"; do
    echo "Searching for files with datestamp pattern: ${date_stamp}"
    for IDX in "${!TEMPFILES[@]}"; do
        TEMP="${TEMPFILES[$IDX]}"
        PREFIX="${PREFIXFILES[$IDX]}"
        # Clear the temporary files before each search
        {
            find ${model_dir}/${PREFIX}${date_stamp}${icon_file_suffix} ! -name "*.bck*" >> "$TEMP"
        } &

    done
    # Wait for all background processes to complete
    wait
done

# Read results from temporary files back into arrays
mapfile -t TAS_FILES < "$TAS_TEMP"
mapfile -t CLT_FILES < "$CLT_TEMP"
mapfile -t PR_FILES < "$PR_TEMP"
mapfile -t RLUT_FILES < "$RLUT_TEMP"
mapfile -t UAS_FILES < "$UAS_TEMP"
mapfile -t VAS_FILES < "$VAS_TEMP"
mapfile -t UA300HPA_FILES < "$UA300HPA_TEMP"
mapfile -t ZG500HPA_FILES < "$ZG500HPA_TEMP"
mapfile -t SICONC_FILES < "$SICONC_TEMP"
mapfile -t ZOS_FILES < "$ZOS_TEMP"
mapfile -t TOS_FILES < "$TOS_TEMP"
mapfile -t MLOTST_FILES < "$MLOTST_TEMP"
mapfile -t TO_FILES < "$TO_TEMP"
mapfile -t SO_FILES < "$SO_TEMP"

rm "$TAS_TEMP" "$CLT_TEMP" "$PR_TEMP" "$RLUT_TEMP" "$UAS_TEMP" "$VAS_TEMP" \
   "$UA300HPA_TEMP" "$ZG500HPA_TEMP" \
   "$SICONC_TEMP" "$ZOS_TEMP" "$TOS_TEMP" "$MLOTST_TEMP" \
   "$TO_TEMP" "$SO_TEMP"



echo "##################################\n"
echo "# Construct grid weights         #\n"
echo "##################################\n"

echo "Constructing interpolation weights for 2D atmospheric variables"

export ATM_2D_WGHTS="${tmpdir}/ATM_2D_weights.nc"
echo "Weights will be saved to: ${ATM_2D_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -selvar,t_s "${TAS_FILES[0]}" "${ATM_2D_WGHTS}"

export OCE_2D_WGHTS="${tmpdir}/OCE_2D_weights.nc"
echo "Standard weights will be saved to: ${OCE_2D_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -setctomiss,0 -selvar,to "${MLOTST_FILES[0]}" "${OCE_2D_WGHTS}"

# SI_WGHTS are used for sea ice and mixed layer depth.
export SI_WGHTS="${tmpdir}/SI_weights.nc"
echo "Sea ice weights will be saved to: ${SI_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -selvar,conc "${SICONC_FILES[0]}" "${SI_WGHTS}"

export ZOS_WGHTS="${tmpdir}/ZOS_weights.nc"
echo "ssh weights will be saved to: ${ZOS_WGHTS}"
cdo -O -P ${PROCS} -gencon,r180x91 -setctomiss,0 -selvar,ssh "${ZOS_FILES[0]}" "${ZOS_WGHTS}"

export OCE_ML_WGHTS="${tmpdir}/ML_weights.nc"
echo "Weights will be saved to: ${OCE_ML_WGHTS}"
cdo -P ${PROCS} -gencon,r180x91 -intlevel,10,100,1000,4000 -setctomiss,0 -selvar,to "${TO_FILES[0]}" "${OCE_ML_WGHTS}"


echo "##################################\n"
echo "# Defining processing functions  #\n"
echo "##################################\n"

# Define the regridding functions for each variable
tas_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"

    echo ""
    echo "Remapping: tas"
    out_file="${tmpdir}/tas_gr2_${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -chname,t_s,tas -selvar,t_s "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi
}


clt_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Remapping: clt"
    out_file="${tmpdir}/clt_gr2_${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -chname,clct,clt -selvar,"clct" "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi
}


pr_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"
    echo ""
    echo "Remapping: pr"
    out_file="${tmpdir}/pr_gr2_${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -chname,tot_prec_rate,pr -selvar,tot_prec_rate "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi
}


rlut_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"
    echo ""
    echo "Remapping: rlut"
    out_file="${tmpdir}/rlut_gr2_${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
        cdo -P ${PROCS} -mulc,-1 -remap,r180x91,"${ATM_2D_WGHTS}" -chname,thb_t,rlut -selvar,thb_t "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi
}


uas_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Remapping: uas"
    out_file="${tmpdir}/uas_gr2_${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
            cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -sellevel,90 -chname,"u","uas" -selvar,"u" "${in_file}" "${out_file}"

    else
        echo "  skipping remapping"
    fi
}


vas_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Remapping: vas"
    out_file="${tmpdir}/vas_gr2_${filename}"
    check_for_and_remove_incomplete_files "${out_file}"
    if [ ! -e "${out_file}" ];
    then
        echo "Remapped output will be saved to: ${out_file}"
            cdo -P ${PROCS} -remap,r180x91,"${ATM_2D_WGHTS}" -sellevel,90 -chname,"v","vas" -selvar,"v" "${in_file}" "${out_file}"
    else
        echo "  skipping remapping"
    fi
}


ua300hPa_processing(){
    in_file=$1
    sister_file="${in_file/_atm_3d_ml_/_atm_2d_ml_}"  # Create the sister file by replacing _atm_3d_ml_ with _atm_2d_ml_ in the filename
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on ${in_file}"

    echo ""
    echo "Remapping: ua (300 hPa)"
    ua300_out="${tmpdir}/ua_gr2_${filename}"
    check_for_and_remove_incomplete_files "${ua300_out}"
    if [ ! -e "${ua300_out}" ];
    then
        echo "Remapped output will be saved to: ${ua300_out}"
        cdo -P ${PROCS} -chname,u,ua -remap,r180x91,"${ATM_2D_WGHTS}" -ap2pl,30000 -merge -selvar,u,pres "${in_file}" -selvar,pres_sfc "${sister_file}" "${ua300_out}"
    else
        echo "  skipping remapping"
    fi
}


zg500hPa_processing(){
    in_file=$1
    sister_file="${in_file/_atm_3d_ml_/_atm_2d_ml_}"  # Create the sister file by replacing _atm_3d_ml_ with _atm_2d_ml_ in the filename
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on ${in_file}"

    echo ""
    echo "Remapping: zg (500 hPa)"
    zg500_out="${tmpdir}/zg_gr2_${filename}"
    check_for_and_remove_incomplete_files "${zg500_out}"
    if [ ! -e "${zg500_out}" ];
    then
        echo "Remapped output will be saved to: ${zg500_out}"
        # The setmisstoc part here shouldn't strictly be there; however, without it 
        # the remap weights have to be recomputed for every timestep...
        cdo -P "${PROCS}" -remap,r180x91,"${ATM_2D_WGHTS}" -setmisstoc,5500 -chname,z_mc,zg -selvar,z_mc -ap2pl,50000 -merge -selvar,z_mc "${atm_zg_file}" -merge [ -selvar,pres "${in_file}" -selvar,pres_sfc "${sister_file}" ] "${zg500_out}"
    else
        echo "  skipping remapping"
    fi


}


siconc_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"
    
    echo ""
    echo "Remapping: siconc"
    siconc_out="${tmpdir}/siconc_gr2_${filename}"
    check_for_and_remove_incomplete_files "${siconc_out}"
    if [ ! -e "${siconc_out}" ];
    then
        echo "Remapped output will be saved to: ${siconc_out}"
        cdo -P ${PROCS} -mulc,100 -remap,r180x91,"${SI_WGHTS}" -chname,conc,siconc -selvar,conc "${in_file}" "${siconc_out}"
    else
        echo "  skipping remapping"
    fi
}


mlotst_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"

    echo ""
    echo "Remapping: mlotst"
    mlotst_out="${tmpdir}/mlotst_gr2_${filename}"
    check_for_and_remove_incomplete_files "${mlotst_out}"
    if [ ! -e "${mlotst_out}" ];
    then
        echo "Remapped output will be saved to: ${mlotst_out}"
        cdo -P ${PROCS} -remap,r180x91,"${SI_WGHTS}" -selvar,mlotst "${in_file}" "${mlotst_out}"
    else
        echo "  skipping remapping"
    fi
}


tos_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"

    echo ""
    echo "Remapping: tos"
    tos_out="${tmpdir}/tos_gr2_${filename}"
    check_for_and_remove_incomplete_files "${tos_out}"
    if [ ! -e "${tos_out}" ];
    then
        echo "Remapped output will be saved to: ${tos_out}"
        cdo -P ${PROCS} -remap,r180x91,"${OCE_2D_WGHTS}" -setctomiss,0 -chname,to,tos -sellevel,1 -selvar,to "${in_file}" "${tos_out}"
    else
        echo "  skipping remapping"
    fi
}


zos_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on: ${in_file}"

    echo ""
    echo "Remapping: zos"
    zos_out="${tmpdir}/zos_gr2_${filename}"
    check_for_and_remove_incomplete_files "${zos_out}"
    if [ ! -e "${zos_out}" ];
    then
        echo "Remapped output will be saved to: ${zos_out}"
        cdo -P ${PROCS} -remap,r180x91,"${ZOS_WGHTS}" -setctomiss,0 -chname,ssh,zos -selvar,ssh "${in_file}" "${zos_out}"
    else
        echo "  skipping remapping"
    fi
}


to_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on ${filename}"

    echo ""
    echo "Remapping: thetao"
    thetao_out="${tmpdir}/thetao_gr2_${filename}"
    check_for_and_remove_incomplete_files "${thetao_out}"
    if [ ! -e "${thetao_out}" ];
    then
        echo "Remapped output will be saved to: ${thetao_out}"
        cdo -P ${PROCS} -remap,r180x91,"${OCE_ML_WGHTS}" -intlevel,10,100,1000,4000 -setctomiss,0 -chname,to,thetao -selvar,to "${in_file}" "${thetao_out}"
    else
        echo "  skipping remapping"
    fi
}


so_processing() {
    in_file=$1
    filename=$(basename "${in_file}")
    echo ""
    echo "Operating on ${filename}"

    echo ""
    echo "Remapping: so"
    so_out="${tmpdir}/so_gr2_${filename}"
    check_for_and_remove_incomplete_files "${so_out}"
    if [ ! -e "${so_out}" ];
    then
        echo "Remapped output will be saved to: ${so_out}"
        cdo -P ${PROCS} -remap,r180x91,"${OCE_ML_WGHTS}" -intlevel,10,100,1000,4000 -setctomiss,0 -selvar,so "${in_file}" "${so_out}"
    else
        echo "  skipping remapping"
    fi

}


# Export the functions just defined
export -f tas_processing
export -f clt_processing
export -f pr_processing
export -f rlut_processing
export -f uas_processing
export -f vas_processing
export -f ua300hPa_processing
export -f zg500hPa_processing
export -f siconc_processing
export -f mlotst_processing
export -f tos_processing
export -f zos_processing
export -f to_processing
export -f so_processing


echo "##################################\n"
echo "# Executing processing functions #\n"
echo "##################################\n"
# Use parallel to exexute the initial regridding.
parallel --jobs $BATCH_SIZE "tas_processing {}" ::: "${TAS_FILES[@]}"
parallel --jobs $BATCH_SIZE "clt_processing {}" ::: "${CLT_FILES[@]}"
parallel --jobs $BATCH_SIZE "pr_processing {}" ::: "${PR_FILES[@]}"
parallel --jobs $BATCH_SIZE "rlut_processing {}" ::: "${RLUT_FILES[@]}"
parallel --jobs $BATCH_SIZE "uas_processing {}" ::: "${UAS_FILES[@]}"
parallel --jobs $BATCH_SIZE "vas_processing {}" ::: "${VAS_FILES[@]}"

parallel --jobs $BATCH_SIZE "ua300hPa_processing {}" ::: "${UA300HPA_FILES[@]}"
parallel --jobs $BATCH_SIZE "zg500hPa_processing {}" ::: "${ZG500HPA_FILES[@]}"

parallel --jobs $BATCH_SIZE "siconc_processing {}" ::: "${SICONC_FILES[@]}"
parallel --jobs $BATCH_SIZE "mlotst_processing {}" ::: "${MLOTST_FILES[@]}"
parallel --jobs $BATCH_SIZE "tos_processing {}" ::: "${TOS_FILES[@]}"
parallel --jobs $BATCH_SIZE "zos_processing {}" ::: "${ZOS_FILES[@]}"

parallel --jobs $BATCH_SIZE "to_processing {}" ::: "${TO_FILES[@]}"
parallel --jobs $BATCH_SIZE "so_processing {}" ::: "${SO_FILES[@]}"


echo "##################################\n"
echo "# Merging files                  #\n"
echo "##################################\n"
# Use CDO to merge and process the remapped files into CMPITool formatted outputs.
# ATM 2D
echo ""
echo "Merging remapped ML atmospheric data into CMPITool formatted files"
for var in tas pr clt rlut uas vas;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -yseasmean -selyear,${first_year}/${last_year} -shifttime,-1seconds -mergetime "${tmpdir}/${var}_gr2_*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"

done


# ATM ML
# ua at 300 hPa
echo "Files being saved into: ${outdir}/ua_${model_name}_${first_year}01-${last_year}12_300hPa_<<season>>.nc"
cdo -O -P ${PROCS} -splitseas -yseasmean -selyear,${first_year}/${last_year} -shifttime,-1seconds -mergetime "${tmpdir}/ua_gr2_*.nc" "${outdir}/ua_${model_name}_${first_year}01-${last_year}12_300hPa_"

# zg at 500 hPa
echo "Files being saved into: ${outdir}/zg_${model_name}_${first_year}01-${last_year}12_500hPa_<<season>>.nc"
cdo -O -P ${PROCS} -splitseas -yseasmean -selyear,${first_year}/${last_year} -shifttime,-1seconds -mergetime "${tmpdir}/zg_gr2_*.nc" "${outdir}/zg_${model_name}_${first_year}01-${last_year}12_500hPa_"


# OCE 2D
echo ""
echo "Merging remapped 2D oceanic data into CMPITool formatted files"
for var in siconc mlotst;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -yseasmean -selyear,${first_year}/${last_year}  -shifttime,-1seconds -mergetime "${tmpdir}/${var}_gr2_*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"
done

# Separate from above as we calculate the std for these variables.
for var in zos tos ;
do
    echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_<<season>>.nc"
    cdo -O -P ${PROCS} -splitseas -yseasstd -selyear,${first_year}/${last_year} -shifttime,-1seconds -mergetime "${tmpdir}/${var}_gr2_*.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_surface_"
done


# OCE ML
echo ""
echo "Merging remapped ML oceanic data into CMPITool formatted files"
for var in thetao so;
do
    cdo -O -P ${PROCS} -mergetime "${tmpdir}/${var}_gr2_*.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12.nc"
    cdo -O -P ${PROCS} -splitlevel "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_000010.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_10m.nc"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_000100.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_100m.nc"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_001000.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_1000m.nc"
    mv "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_004000.nc" "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_4000m.nc"

    for level in 10 100 1000 4000;
    do
        echo "Files being saved into: ${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_${level}m_<<season>>.nc"
        cdo -O -P ${PROCS} -splitseas -yseasmean -selyear,${first_year}/${last_year} -shifttime,-1seconds "${tmpdir}/${var}_${model_name}_${first_year}01-${last_year}12_${level}m.nc" "${outdir}/${var}_${model_name}_${first_year}01-${last_year}12_${level}m_"
    done
done


echo ""
echo "Processing complete"
echo "CMPITool ready files have been saved in: ${outdir} "
echo "Temporary files have been saved in: ${tmpdir}"
echo "If you are satisfied the processing is complete you may clean-up any     "
echo "temporary files by running 'rm -r ${tmpdir}'"
echo ""
