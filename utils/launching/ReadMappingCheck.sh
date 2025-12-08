#!/bin/bash

########### FUNCTIONS ##########

checkBedFormat(){
  nb_col_bed=$(awk '{print NF}' $BED | sort | uniq)
  if [[ $nb_col_bed != 3 ]] ; then
    echo -e "\nERROR: Your bed file (${BED}) does not seem to be properly formated." >&2
    reminderMsg $RM_bed_msg
    exit1wMsg
  fi

}

CSB_extraChecks(){
  if ! isTrue $CREATE_SUB_BAMS && ! isFalse $CREATE_SUB_BAMS ; then
    exitTrueFalseError "CREATE_SUB_BAMS" "$RM_CREATE_SUB_BAMS_msg"
  fi

  if [[ "$CREATE_SUB_BAMS" == "TRUE" || "$CREATE_SUB_BAMS" == "True" || "$CREATE_SUB_BAMS" == "true" ]] ; then
    if [[ -z "$BED" && (-z "$BED_MIN_MEAN_COV" || -z "$BED_MIN_DIST" || -z "$BED_MIN_LENGTH") ]] ; then
      echo -e "\nERROR: CREATE_SUB_BAM was set to TRUE but neither the bed file nor the parameters to automatically create it were provided in your config file (${CONFIG}). Please either provide a bed file, or values for BED_MIN_MEAN_COV, BED_MIN_DIST and BED_MIN_LENGTH, or set CREATE_SUB_BAM to FALSE." >&2
      exit1wMsg
    fi
    if [[ -n "$BED" && (-n "$BED_MIN_MEAN_COV" || -n "$BED_MIN_DIST" || -n "$BED_MIN_LENGTH") ]] ; then
      echo -e "\nERROR: You provided both the bed file and the parameters to automatically create it in your config file (${CONFIG}). Please EITHER provide a bed file, OR values for BED_MIN_MEAN_COV, BED_MIN_DIST and BED_MIN_LENGTH." >&2
      exit1wMsg
    fi
  fi
}

MAPPER_extra_checks() {
  if ! isInList $MAPPER "bwa-mem2_mem" "bwa_mem" "bowtie2" "minimap2"; then
    echo -e "\nERROR: The MAPPER (${MAPPER}) provided in your config file (${CONFIG}) is unknown." >&2
    reminderMsg $RM_MAPPER_msg
    exit1wMsg
  fi
}

checkDuplicatesHandling(){
  # **REMOVE_DUP_MARKDUPLICATES**
  if ! isTrue $REMOVE_DUP_MARKDUPLICATES && ! isFalse $REMOVE_DUP_MARKDUPLICATES ; then
    exitTrueFalseError "REMOVE_DUP_MARKDUPLICATES" "$RM_REMOVE_DUP_MARKDUPLICATES_msg"
  fi

  # **REMOVE_DUP_UMI**
  if ! isTrue $REMOVE_DUP_UMI && ! isFalse $REMOVE_DUP_UMI ; then
    exitTrueFalseError "REMOVE_DUP_UMI" "$RM_REMOVE_DUP_UMI_msg"
  fi

  if isTrue $REMOVE_DUP_UMI && isTrue $REMOVE_DUP_MARKDUPLICATES ; then
    echo -e "\nERROR: You cannot set both REMOVE_DUP_MARKDUPLICATES and REMOVE_DUP_UMI variable to TRUE in your config file (${CONFIG})." >&2
    reminderMsg $RM_REMOVE_DUP_MARKDUPLICATES_msg"\n"$RM_REMOVE_DUP_UMI_msg
    exit1wMsg
  fi
}

checkPAIRED_END() {
  if isTrue $PAIRED_END; then
    echo -e "\nINFO: Paired end data is expected (PAIRED_END set to TRUE)\n" >&2
  elif isFalse $PAIRED_END; then
    echo -e "\nINFO: Single end data is expected (PAIRED_END set to FALSE)\n" >&2
  else
    exitTrueFalseError "PAIRED_END" "$RM_PAIRED_END_msg"
    exit1wMsg
  fi
}

checkDefaultTRIM_DIRS(){
  if [[ -z "$TRIM_DIRS" ]] ; then
    TRIM_DIRS="${CWD}/WORKFLOWS_OUTPUTS/DATA_CLEANING/DEMULT_TRIM"
    if [[ ! -d "$TRIM_DIRS" ]] ; then
      echo -e "\nERROR: You did not specify any TRIM_DIR folder in your config file (${CONFIG}), but the default TRIM_DIR folder (${TRIM_DIRS}) does not exist. Please specify your TRIM_DIRS path(s) in the config_file." >&2
      exit1wMsg
    fi
  fi
}


checkFastqSE(){
  set +eo pipefail
  nb_fastq=$(ls ${TRIM_DIR}/*.fastq.gz 2>/dev/null | wc -l)
  nb_fastq_R1_obs=$(ls ${TRIM_DIR}/*R1*fastq.gz 2>/dev/null | wc -l)
  nb_fastq_R2_obs=$(ls ${TRIM_DIR}/*R2*fastq.gz 2>/dev/null | wc -l)
  set -eo pipefail
  if [[ "$nb_fastq" = 0 ]] ; then
    echo -e "\nERROR: The TRIM_DIR folder (${TRIM_DIR}) is either empty or the fastq files it contains are not properly named. Input fastq files must end with '.fastq.gz'." >&2
    exit1wMsg
  fi
  if [[ "$nb_fastq_R1_obs" > 0 && "$nb_fastq_R2_obs" > 0 ]] ; then
    echo -e "\nWARNING: You set PAIRED_END to FALSE but it appears that your data may be paired: 'R1' and 'R2' patterns were found in their names." >&2
    echo -e "Your fastq files will be mapped as single end data. If your data is paired, please set PAIRED_END to TRUE.\n" >&2
  fi
}


########### MAIN ##########

## General variables (PAIRED_END) ##

# **PAIRED_END**
checkPAIRED_END


## Input data (TRIM_DIR, fastq files, REFERENCE) ##

# **TRIM_DIR**
checkDefaultTRIM_DIRS

for TRIM_DIR in $TRIM_DIRS ; do
  checkMissingDir "$TRIM_DIR" "config" "TRIM_DIRS"
  if isTrue $PAIRED_END ; then
    checkFastqPE "$TRIM_DIR" "TRIM_DIR"
  else
    checkFastqSE
  fi
done

# **REFERENCE**
checkMissingValue "$REFERENCE" "$(echo \$REFERENCE | sed 's/\$//')"

checkMissingFile "$REFERENCE" "$(echo \$REFERENCE | sed 's/\$//')"

checkExtension "$REFERENCE" "$(echo \$REFERENCE | sed 's/\$//')" "fasta" "${fasta_ext[@]}"


## Zones and extraction (BED, CREATE_SUB_BAMS)
# **BED**
# Targeted zones bed file (optionnal)
if [[ -n "$BED" ]] ; then
  checkMissingFile "$BED" "$(echo \$BED | sed 's/\$//')"
  checkBedFormat
fi


# **CREATE_SUB_BAMS**
checkMissingValue "$CREATE_SUB_BAMS" "$(echo \$CREATE_SUB_BAMS | sed 's/\$//')" "$RM_CREATE_SUB_BAMS_msg"

CSB_extraChecks

## Mapping parameters ##
# **MAPPER**
checkMissingValue "$MAPPER" "$(echo \$MAPPER | sed 's/\$//')" "$RM_MAPPER_msg"

MAPPER_extra_checks

# **DEALING WITH DUPLICATES**
checkDuplicatesHandling


