exit1wMsg() {
  echo -e "\nExiting.\n" >&2
  exit 1
}

isAvailable() {
  local tool_name=$1
  local tool_cmd=$2
  if ! command -v $tool_cmd &> /dev/null; then
    echo -e "\nERROR: $tool_name is not available. You must install it, or make it available to your working environment (eg: module load it or activate it with conda)." >&2
    exit1wMsg
  fi
}

dlImageSylabs() {
  local sylabs_image=$1
  local expected_image=$2
  local image_dir=$(dirname $expected_image)

  if [[ ! -f "${expected_image}" ]] ; then

    isAvailable "Singularity/Apptainer" "singularity"

    mkdir -p "${image_dir}"
    echo -e "\nDownloading the Singularity image (${sylabs_image}) from Sylabs cloud..."
    singularity pull ${expected_image} ${sylabs_image}
    if [[ $? -ne 0 ]]; then
      echo -e "\ERROR: Failed to download the Singularity image."
      exit1wMsg
    fi
  fi
}

rmCR() {
  local file=$1
  if grep -q $'\r' ${file}; then
    echo "Removing windows carriage returns in ${file}..."
    sed -i 's/\r$//g' $file
    sed -i 's/\r/\n/g' $file
  fi
}

makeExecutable() {
  local script=$1
  if [[ "${script}" == *.sh && ! -x "${script}" ]] ; then
    echo "Making "${script}" executable..."
    chmod 755 "${script}"
  fi
}


reminderMsg(){
    local msgs=("$@")
    echo "As a reminder:" >&2
    echo -e "${msgs[@]}" >&2
    # for msg in "${msgs[@]}"; do
    #     echo -e $msg
    # done
}

missingValueErrorMsg() {
    local value_name=$1
    shift
    local msgs="$@"
    echo -e "\nERROR: The ${value_name} variable is missing in your config file (${CONFIG})." >&2
    if [[ -n $msgs ]] ; then
        reminderMsg "$msgs"
    fi
}


checkMissingValue() {
    if [[ -z "$1" ]] ; then
        local value_name=$2
        shift 2
        local msgs=("$@")
        missingValueErrorMsg ${value_name} ${msgs}
        exit1wMsg
    fi
}


missingFileErrorMsg() {
    local file=$1
    local file_var_name=$2
    echo -e "\nERROR: The ${file_var_name} file (${file}) provided in your config file (${CONFIG}) does not exist." >&2
}

checkMissingFile(){
    if [[ -n "$1" && ! -f "$1" ]] ; then
        local file=$1
        local file_var_name=$2
        missingFileErrorMsg $file $file_var_name
        exit1wMsg
    fi
}


missingConfDirErrorMsg() {
    local dir=$1
    local dir_var_name=$2
    echo -e "\nERROR: The ${dir_var_name} directory (${dir}) provided in your config file (${CONFIG}) does not exist." >&2
}

missingGeCKOsubdirErrorMsg() {
    local dir=$1
    local dir_name=$(basename $dir)
    echo -e "\nERROR: No ${dir_name} folder was found in the provided workflow path (${GeCKO_path}). Please clone or copy the whole repository from GitHub: ${repo} containing all sub-directories." >&2
}


checkMissingDir(){
    local dir=$1
    local context=$2
    if [[ ! -d "$dir" ]] ; then
        if [[ $context == "config" ]]; then
            dir_var_name=$3
            missingConfDirErrorMsg $dir $dir_var_name
        elif [[ $context == "GeCKOdir" ]]; then
            missingGeCKOsubdirErrorMsg $dir
        fi
        exit1wMsg
    fi
}

isInList() {
    local value=$1
    shift
    local possible_values=("$@")
    local possible_value
    for possible_value in "${possible_values[@]}"; do
        if [[ "$value" == "$possible_value" ]]; then
            return 0
        fi
    done

    return 1
}

isTrue(){
    isInList $1 "TRUE" "True" "true"
}

isFalse(){
    isInList $1 "FALSE" "False" "false"
}

checkExtension() {
    local file=$1
    local file_var_name=$2
    local ext_name=$3
    shift 3
    local extensions=("$@")

    for ext in "${extensions[@]}"; do
        if [[ "$file" == *"$ext" ]]; then
            return 0
        fi
    done

    # if file has none of the possible extensions:
    extensions_for_print=$(echo "${extensions[@]}" | sed "s/\([^ ]\+\)/'&'/g" | sed 's/ /, /g' | sed 's/\(.*\),/\1 or/')

    echo -e "\nERROR: The $file_var_name file (${file}) provided in your config file (${CONFIG}) does not have a proper ${ext_name} extension. Please make sure the file is a ${ext_name} file and ends with ${extensions_for_print}." >&2
    exit1wMsg
}

# checkFastaExt(){
#     checkExtension $1 "fasta" ".fasta" ".fas" ".fa"
# }

exitTrueFalseError() {
    local var_name=$1
    shift
    local msgs=("$@")
    echo -e "\nERROR: The ${var_name} variable is either missing or incorrect in your config file (${CONFIG}). Please set it to TRUE or FALSE." >&2
    if [[ -n $msgs ]] ; then
        reminderMsg "$msgs"
    fi
    exit1wMsg
}

R1R2mismatchExit(){
    dir=$1
    dirname=$2
    echo -e "\nERROR: Input R1 and R2 fastq files do not seem to match. A set of matching *.R1.fastq.gz and *.R2.fastq.gz are expected in the ${dirname} folder (${dir})." >&2
    exit1wMsg
}

checkFastqPE(){
    dir=$1
    dirname=$2
    set +eo pipefail
    nb_fastq_R1_obs=$(ls ${dir}/*.R1.fastq.gz 2>/dev/null | wc -l)
    nb_fastq_R2_obs=$(ls ${dir}/*.R2.fastq.gz 2>/dev/null | wc -l)
    set +eo pipefail
    if [[ $nb_fastq_R1_obs -eq 0 || $nb_fastq_R2_obs -eq 0 ]] ; then
        echo -e "\nERROR: The provided ${dirname} (${dir}) is either empty or the fastq files it contains are not properly named. Input demultiplexed fastq files must end with '.R1.fastq.gz' and '.R2.fastq.gz'." >&2
        exit1wMsg
    else
        fastq_R1_list=$(ls -1 ${dir}/*.R1.fastq.gz 2>/dev/null | xargs -n1 basename 2>/dev/null)
        fastq_R2_list_exp=$(echo $fastq_R1_list | sed 's/.R1./.R2./g')
        nb_fastq_R2_exp=$(echo $fastq_R2_list_exp | wc -w)
        if [[ $nb_fastq_R2_obs != $nb_fastq_R2_exp ]] ; then
            R1R2mismatchExit $dir $dirname
        fi
        for fastq_r2 in $fastq_R2_list_exp ; do
            if [[ ! -f ${dir}/$fastq_r2 ]] ; then
            R1R2mismatchExit $dir $dirname
            fi
        done
    fi
}
