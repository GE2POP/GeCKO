#!/bin/bash

########### FUNCTIONS ##########

checkDemult_PE(){
  if [[ -z "$DEMULT_DIR" ]] ; then
    echo -e "\nERROR: You must either provide FASTQ_R1 and FASTQ_R2 or DEMULT_DIR in the config_file, but they were all left blank." >&2
    exit1wMsg
  elif [[ ! -d "$DEMULT_DIR" ]] ; then
    echo -e "\nERROR: the DEMULT_DIR parameter provided in the config file (${DEMULT_DIR}) is not a valid path. Please make sure the directory exists and the path is correctly written." >&2
    exit1wMsg
  else
    checkFastqPE "$DEMULT_DIR" "DEMULT_DIR"
  fi
}

checkMult_PE(){
  if [[ ! -f "$FASTQ_R1" || ! -f "$FASTQ_R2" ]] ; then
    echo -e "\nERROR: At least one the two input fastq files ${FASTQ_R1} and ${FASTQ_R2} provided in the config file does not exist. Please make sure the files exist and their path is correct." >&2
    exit1wMsg
  elif [[ "$FASTQ_R1" != *_R1.fastq.gz || "$FASTQ_R2" != *_R2.fastq.gz ]] ; then
    echo -e "\nERROR: Provided FASTQ_R1 and FASTQ_R2 (${FASTQ_R1} and ${FASTQ_R2}) are not properly named. Multiplexed fastq files must end with _R1.fastq.gz and _R2.fastq.gz." >&2
    exit1wMsg
  else
    R1_basename=$(basename $FASTQ_R1 _R1.fastq.gz)
    R2_basename=$(basename $FASTQ_R2 _R2.fastq.gz)
    if [[ "$R1_basename" != "$R2_basename" ]] ; then
      echo -e "\nERROR: Provided FASTQ_R1 and FASTQ_R2 names do not match: ${R1_basename} != ${R2_basename}." >&2
      exit1wMsg
    fi
  fi
}


checkPEconfig(){
  if [[ (-n "$FASTQ_R1" || -n "$FASTQ_R2") && -n "$DEMULT_DIR" ]] ; then
    echo -e "\nERROR: You provided both FASTQ_R1 and/or FASTQ_R2 and DEMULT_DIR in the config_file. Please provide either FASTQ_R1 and FASTQ_R2 in case of multiplexed data, or DEMULT_DIR in case of demultiplexed data." >&2
    exit1wMsg
  fi
  if [[ -z "$FASTQ_R1" || -z "$FASTQ_R2" ]] ; then
    checkDemult_PE
  else
    checkMult_PE
  fi
}

checkDefaultFastqDir_SE(){
  DEMULT_DIR=$(grep "^DEMULT_DIR:" $CONFIG | sed 's/#.*$//' | cut -d ' ' -f2 | sed 's/"//g')
  if [[ -z "$DEMULT_DIR" ]] ; then
    echo -e "\nERROR: You must provide either FASTQ or DEMULT_DIR in the config_file, but they were both left blank." >&2
    exit1wMsg
  else
    nb_fastq=$(ls ${DEMULT_DIR}/*.fastq.gz 2>/dev/null | wc -l)
    if [[ "$nb_fastq" -eq 0 ]] ; then
      echo -e "\nERROR: fastq files could not be found in ${DEMULT_DIR}. Input demultiplexed fastq files must end with '.fastq.gz'." >&2
      exit1wMsg
    fi
  fi
}

checkSEconfig(){
  if [[ -n "$FASTQ" && -n "$DEMULT_DIR" ]] ; then
    echo -e "\nERROR: You provided both FASTQ and DEMULT_DIR in the config_file. Please provide either FASTQ in case of multiplexed data, or DEMULT_DIR in case of demultiplexed data." >&2
    exit1wMsg
  fi
  if [[ -z "$FASTQ" ]] ; then
    checkDefaultFastqDir_SE
  elif [[ ! -f "$FASTQ" ]] ; then
    echo -e "\nERROR: The input fastq file ${FASTQ} provided in the config file does not exist. Please make sure the file exists and its path is correct." >&2
    exit1wMsg
  elif [[ "$FASTQ" != *.fastq.gz ]] ; then
      echo -e "\nERROR: Provided FASTQ (${FASTQ}) is not properly named. Multiplexed fastq files must end with .fastq.gz" >&2
      exit1wMsg
  fi
}

exitSampleNotFoundAF(){
  local sample=$1
  echo -e "\nERROR: ${sample} could not be found in your ADAPTER_FILE. Please make sure all your samples appear in your ADAPTER_FILE." >&2
  exit1wMsg
}

exitFastqNotFound(){
  local sample=$1
  local R1R2
  if isTrue $PAIRED_END ; then R1R2=" R1 and R2"; fi
  echo -e "\nERROR: the ${sample}${R1R2} fastq.gz could not be found in ${DEMULT_DIR}. Please make sure the names match and the fastq files are named in the following format: ${sample}.R1.fastq.gz, ${sample}.R2.fastq.gz." >&2
  exit1wMsg
}

checkAdaptersAndFastqsMatchPE(){
  local samples="$1"
  for sample in $samples ; do
    fastq_R1="${DEMULT_DIR}/${sample}.R1.fastq.gz"
    fastq_R2="${DEMULT_DIR}/${sample}.R2.fastq.gz"
    if [[ ! -f "$fastq_R1" || ! -f "$fastq_R2" ]] ; then
      exitFastqNotFound $sample
    fi
  done
  for fastq_R1 in $(ls ${DEMULT_DIR}/*.R1.fastq.gz) ; do
    sample=$(basename $fastq_R1 .R1.fastq.gz)
    set +eo pipefail
    nb_row_sample=$(grep -c "$sample" "$ADAPTER_FILE")
    set -eo pipefail
    if [[ $nb_row_sample -eq 0 ]] ; then
      exitSampleNotFoundAF $sample
    fi
  done
}

checkAdaptersAndFastqsMatchSE(){
  for sample in $samples ; do
    fastq="${DEMULT_DIR}/${sample}.fastq.gz"
    if [[ ! -f "$fastq" ]] ; then
      exitFastqNotFound $sample
    fi
  done
  for fastq in $(ls ${DEMULT_DIR}/*fastq.gz) ; do
    sample=$(basename $fastq .fastq.gz)
    set +eo pipefail
    nb_row_sample=$(grep -c "$sample" "$ADAPTER_FILE")
    set -eo pipefail
    if [[ $nb_row_sample -eq 0 ]] ; then
      exitSampleNotFoundAF $sample
    fi
  done
}

checkExpNbCol(){
  local file=$1
  local file_type=$2

  if isTrue $PAIRED_END; then
    data_type="paired end"
    exp_nb_col=3
  else
    data_type="single end"
    exp_nb_col=2
  fi
  local nb_col_file=$(awk -F '\t' '{print NF}' $file | sort | uniq)
  if [[ $nb_col_file != $exp_nb_col ]] ; then
    echo -e "\nERROR: The ${file_type} file (${file}) provided in the config file does not have a proper format. For ${data_type} data, ${exp_nb_col} columns are expected, separated by tabs." >&2
    exit1wMsg
  fi
}

checkBarcode(){
  if [[ -z "$DEMULT_DIR" && -z "$BARCODE_FILE" ]] ; then
    missingValueErrorMsg "BARCODE_FILE"
    exit1wMsg
  fi
  if [[ -n "$BARCODE_FILE" && ! -f "$BARCODE_FILE" ]] ; then
    echo -e "\nERROR: The BARCODE_FILE provided in the config file (${BARCODE_FILE}) does not exist. Please make sure the file exists and its path is correct." >&2
    exit1wMsg
  fi

  if [[ -n "$BARCODE_FILE" ]] ; then
    rmCR $BARCODE_FILE
    checkExpNbCol $BARCODE_FILE "barcode"
  fi
}

checkAdapterFile() {
  checkMissingValue "$ADAPTER_FILE" "$(echo \$ADAPTER_FILE | sed 's/\$//')"

  if [[ -n "$ADAPTER_FILE" && ! -f "$ADAPTER_FILE" ]] ; then
    echo -e "\nERROR: The ADAPTER_FILE provided in the config file (${ADAPTER_FILE}) does not exist. Please make sure the file exists and its path is correct." >&2
    exit1wMsg
  fi
  rmCR $ADAPTER_FILE

  checkExpNbCol $ADAPTER_FILE "adapter"

  if [[ -n "$DEMULT_DIR" ]] ; then
    samples=$(cut -f1 $ADAPTER_FILE)
    if isTrue $PAIRED_END ; then
      checkAdaptersAndFastqsMatchPE "${samples}"
    fi
    if isFalse $PAIRED_END ; then
      checkAdaptersAndFastqsMatchSE "${samples}"
    fi
  fi
}

# countUnmatchingEntries() {
#     local file1=$1
#     local file2=$2 
#     local count=0
#     if output=$(grep -F -x -v -f <(sort "$file1") <(sort "$file2")); then
#         count=$(echo "$output" | wc -l)
#     else # workaround with if/else because if grep finds 0 lines it returns 1 and the script would exit because of set -e pipefail
#         count=0
#     fi
#     echo "$count"
# }

checkBarcodeAdapterMatch(){
  if [[ -n $BARCODE_FILE ]] ; then
    nb_uniq_adapt=$(grep -F -x -v -f <(cut -f1 $BARCODE_FILE | sort) <(cut -f1 $ADAPTER_FILE | sort) || true | wc -l)
    nb_uniq_barcode=$(grep -F -x -v -f <(cut -f1 $ADAPTER_FILE | sort) <(cut -f1 $BARCODE_FILE | sort) || true | wc -l)
    #nb_uniq_adapt=$(countUnmatchingEntries <(cut -f1 $BARCODE_FILE) <(cut -f1 $ADAPTER_FILE))
    #nb_uniq_barcode=$(countUnmatchingEntries <(cut -f1 $ADAPTER_FILE) <(cut -f1 $BARCODE_FILE))
    if [[ $nb_uniq_adapt -gt 0 || $nb_uniq_barcode -gt 0 ]] ; then
      echo -e "\nERROR: The samples names given in the ADAPTER_FILE and the BARCODE_FILE do not match. Please make sure that they are the same." >&2
      exit1wMsg
    fi
  fi
}


checkUMI(){
  if ! isTrue $UMI && ! isFalse $UMI ; then
    exitTrueFalseError "UMI" "$DC_UMI_msg"
  fi
}


########### MAIN ##########

### Config file variables values
FASTQ_R1=$(printAbsolutePath $FASTQ_R1)
FASTQ_R2=$(printAbsolutePath $FASTQ_R2)
DEMULT_DIR=$(printAbsolutePath $DEMULT_DIR)
FASTQ=$(printAbsolutePath $FASTQ)


if [[ "$WORKFLOW_SMK" = "${WORKFLOW}_PairedEnd.smk" ]] ; then 
  checkPEconfig
else 
  checkSEconfig
fi

# DEMULT_SUBSTITUTIONS
if [[ -z "$DEMULT_DIR" && -z "$DEMULT_SUBSTITUTIONS" ]] ; then
  missingValueErrorMsg "DEMULT_SUBSTITUTIONS"
  exit1wMsg
fi

# BARCODE_FILE and ADAPTER_FILE
BARCODE_FILE=$(printAbsolutePath $BARCODE_FILE)
ADAPTER_FILE=$(printAbsolutePath $ADAPTER_FILE)

checkBarcode
checkAdapterFile

# check that BARCODE_FILE and ADAPTER_FILE contain the same samples
checkBarcodeAdapterMatch

# UMI
checkUMI

# TRIMMING_QUAL and TRIMMING_MIN_LENGTH
checkMissingValue "$TRIMMING_QUAL" "$(echo \$TRIMMING_QUAL | sed 's/\$//')"

checkMissingValue "$TRIMMING_MIN_LENGTH" "$(echo \$TRIMMING_MIN_LENGTH | sed 's/\$//')"
