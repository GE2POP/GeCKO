#!/bin/bash

########### FUNCTIONS ##########

getConfigModel(){
	local model_config
	if [[ "$WORKFLOW" = "DataCleaning" ]] ; then
		local PAIRED=$(grep "^PAIRED_END" $CONFIG | cut -f2 -d ' ')
		if isTrue $PAIRED ; then
			model_config="${workflow_path}/SCRIPTS/model_files/config_${WORKFLOW}_PE.yml"
			echo -e "\nINFO: Paired end data is expected (PAIRED_END set to TRUE)\n" >&2
		elif isFalse $PAIRED ; then
			model_config="${workflow_path}/SCRIPTS/model_files/config_${WORKFLOW}_SE.yml"
			echo -e "\nINFO: Single end data is expected (PAIRED_END set to FALSE)\n" >&2
		else
			exitTrueFalseError "PAIRED_END" "$RM_PAIRED_END_msg"
		fi
	else
		model_config="${workflow_path}/SCRIPTS/model_files/config_${WORKFLOW}.yml"
	fi
	echo $model_config
}


exitMissingConfig(){
	echo -e "\nERROR: The workflow config file cannot be found. Please provide your config file with --config-file or place it in a CONFIG folder under the name config_${WORKFLOW}.yml.\n" >&2
	reminderMsg $config_file_help
	exit1wMsg
}


getDefaultConfig(){
	local CONFIG=$1
	if [[ -f "CONFIG/config_${WORKFLOW}.yml" ]] ; then
		CONFIG="CONFIG/config_${WORKFLOW}.yml"
		printAbsolutePath $CONFIG
		printDefaultConfigInfo
	else
		exitMissingConfig
	fi
}

printDefaultConfigInfo(){
	echo -e "\nINFO: The config_${WORKFLOW}.yml file was automatically found in ${CWD}/CONFIG and will be used as the config file for this workflow." >&2
	echo -e "If you would rather use another config file, please provide it with --config-file\n" >&2
}

isParamValueMissing() {
    local param="$1"
	if [[ -z "$param" || "$param" == --* || "$param" == -* ]]; then
 		return 0
	else
		return 1
	fi
}

getProperConfig(){
	local CONFIG=$1
	CONFIG=$(printAbsolutePath $CONFIG)
	if isParamValueMissing $CONFIG ; then
		default_config=$(getDefaultConfig $CONFIG) || exit 1
		echo $default_config
	elif [[ -f "$CONFIG" ]] ; then
		echo $CONFIG
	fi
}

exitInvalidConfig(){
	echo -e "\nERROR: the file given in the --config-file parameter is not valid. Please make sure the file exists and the path is correctly written." >&2
	reminderMsg $config_file_help
	exit1wMsg
}


rmSpaces() {
	local yaml=$1
	if grep -q '  .*' $yaml; then
		echo "Removing extra spaces in ${yaml}..."
		sed -i 's/  */ /g' $yaml
	fi
}

parse_config_yaml() {
    local config_yaml=$1
    local model_config_yaml=$2
	local parse_out

    if ! parse_out=$(singularity exec -B ${GeCKO_path} -B $(pwd) -B $HOME $GeCKO_sif python3 "${checks_path}/parse_yaml.py" "$config_yaml" "$model_config_yaml"); then
        exit1wMsg
    fi
    while IFS=$'\t' read -r key value; do
        export "$key=$value"
    done <<< "$parse_out"
}

exitInvalidWFname(){
	echo -e "\nERROR: The workflow name provided with --workflow is unknown." >&2
	reminderMsg $workflow_help
	exit1wMsg
}


getWFfolderName(){
	local workflow_folder_name=$(grep -w $WORKFLOW ${checks_path}/workflows_list.tsv | cut -f2)
	if [[ -z $workflow_folder_name ]] ; then
		exitInvalidWFname
	fi
	echo $workflow_folder_name
}

isWFparamMissing(){
	if isParamValueMissing $WORKFLOW ; then
		echo -e "\nERROR: the --workflow parameter is missing, please include it in your command." >&2
		reminderMsg $workflow_help
		exit1wMsg
	fi
}

getDCsmkName(){
	if isTrue $PAIRED_END ; then
		echo "${WORKFLOW}_PairedEnd.smk"
	else
		echo "${WORKFLOW}_SingleEnd.smk"
	fi
}

checkClusterProfile(){
	if [[ -n "$CLUSTER_PROFILE" ]] ; then
		if [[ "$JOBS" = 1 ]] ; then
		echo -e "\nWARNING: The workflow will be run with only 1 job allowed at a time. The tasks will not be parallelized. You can increase the maximum number of jobs allowed to be run in parallel with the --jobs option.\n" >&2
		fi
		if [[ -d "$CLUSTER_PROFILE" ]] ; then
			if [[ -f "${CLUSTER_PROFILE}/config.yaml" ]] ; then
				rmCR ${CLUSTER_PROFILE}/config.yaml
				CLUSTER_PROFILE=$(printAbsolutePath $CLUSTER_PROFILE)
				PROFILE="--profile $CLUSTER_PROFILE"
				PROFILE_FILE=${CLUSTER_PROFILE}/config.yaml
			else
				echo -e "\nERROR: $CLUSTER_PROFILE must contain a config.yaml file. Please make sure it exists and it is properly named." >&2
				reminderMsg $cluster_profile_help
				exit1wMsg
			fi
		else
			echo -e "\nERROR: the path given in the --cluster-profile parameter is not valid. Please make sure the folder exists and the path is correctly written." >&2
			reminderMsg $cluster_profile_help
			exit1wMsg
		fi
	else
	PROFILE=""
	PROFILE_FILE="NULL"
	echo -e "\nWARNING: No cluster profile was provided. The pipeline will be run without submitting any job and any parallelization.\n" >&2
	fi
}


########### MAIN ##########

repo="https://github.com/GE2POP/GeCKO"
CWD=$PWD
fasta_ext=(".fasta" ".fas" ".fa")
vcf_ext=(".vcf" ".vcf.gz")
source ${checks_path}/reminders_var.sh


### 1/ WORKFLOW FOLDER AND ITS CONTENTS ###
isWFparamMissing

workflow_folder_name=$(getWFfolderName)

checkMissingDir "${GeCKO_path}/${workflow_folder_name}/" "GeCKOdir"


workflow_path="${GeCKO_path}/${workflow_folder_name}/WORKFLOW"
workflow_scripts_folder="${workflow_path}/SCRIPTS"

for file in $(find ${workflow_scripts_folder} -type f) ; do
	rmCR $file
	makeExecutable $file
done




### 2/ CONFIG_FILE ###
if [[ -n $CONFIG && ! -f "$CONFIG" ]] ; then
	exitInvalidConfig
fi
proper_config=$(getProperConfig $CONFIG) || exit 1
CONFIG=$proper_config

rmSpaces $CONFIG

rmCR $CONFIG

#checkConfigFormat >> fait par script python ?


# Import the user's variables
model_config=$(getConfigModel)
parse_config_yaml $CONFIG $model_config


### 3/ WORKFLOW_SMK

if [[ "$WORKFLOW" = "DataCleaning" ]] ; then
	WORKFLOW_SMK=$(getDCsmkName)
else
	WORKFLOW_SMK="${WORKFLOW}.smk"
fi

if [[ ! -f "${workflow_path}/${WORKFLOW_SMK}" ]] ; then
	exitInvalidWFname
fi

rmCR ${workflow_path}/$WORKFLOW_SMK


### 4/ CLUSTER_PROFILE and jobs
checkClusterProfile
