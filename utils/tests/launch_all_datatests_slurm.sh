#!/usr/bin/env bash

# Usage:  utils/tests/launch_all_datatests_slurm.sh --gecko-path . --partition agap_normal --image-version 1.2.1 [--clean-outputs]
# Depends on a test_subfolders.txt file expected in a CONFIG directory next to the script

set -euo pipefail

module purge
#module load singularity/3.6.3

# ------- CONFIG ------- #
configPath=$(dirname "$0")"/CONFIG"
dirsFile=${configPath}/test_subfolders.txt

declare -A workflows
workflows["DATA_CLEANING"]="DataCleaning DC"
workflows["READ_MAPPING"]="ReadMapping RM"
workflows["VARIANT_CALLING"]="VariantCalling VC"
workflows["VCF_FILTERING"]="VcfFiltering VF"

workflowMotifs=$(echo "${!workflows[@]}" | sed 's/ /|/g')


# -------- ARGUMENTS -------- #

shouldCleanOutputs="FALSE"

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --gecko-path)
    geckoPath=$(realpath "$2")
    shift
    shift
    ;;
    --partition)
    partition="$2"
    shift
    shift
    ;;
    --image-version)
    imageVersion="$2"
    shift
    shift
    ;;
    --clean-outputs)
    shouldCleanOutputs="TRUE"
    shift
    ;;
    -*|*)
    echo -e "\nWARNING: $1 option is unknown and will be ignored.\n"
    shift
    ;;
esac
done

# -------- FUNCTIONS -------- #

sourceDependencies(){
    local geckoPath="$1"
    source "${geckoPath}/utils/launching/launching_utils.sh"
    source "${geckoPath}/utils/utils.sh"
}

cleanLogs(){
    dir="$1"
    echo "Removing ${dir} previous log files..."
    rm -fr "${dir}"/slurm*.out "${dir}"/Logs_*Workflow
}

cleanOutputs(){
    dir="$1"
    echo "Removing ${dir} previous output files..."
    rm -fr "${dir}/WORKFLOWS_OUTPUTS"
}

cleanOldFiles() {
    local geckoPath="$1"
    local shouldCleanOutputs="$2"
    cd "$geckoPath"
    for dir in "${testDirs[@]}" ; do
        cleanLogs "$dir"
        if [ "$shouldCleanOutputs" == "TRUE" ] ; then
            cleanOutputs "$dir"
        fi
    done
    cdSilent -
}


sbatchRunGecko(){
    local runGeCKO="$1"
    local workflowName="$2"
    local workflowPrefix="$3"
    local partition="$4"
    shift 4
    local extraOptions=("$@")
    
    runGeCKOcmd="sbatch --partition=$partition --wrap=\"${runGeCKO} --workflow ${workflowName} --config-file CONFIG/config_${workflowName}.yml --cluster-profile CONFIG/${workflowPrefix}_CLUSTER_PROFILE_SLURM_ACCOUNT ${extraOptions}\""
    echo "$runGeCKOcmd"
    eval "$runGeCKOcmd"
}

sbatchRunGeckoTest(){
    local runGeCKO="$1"
    local workflowName="$2"
    local workflowPrefix="$3"
    local partition="$4"
    sbatchRunGecko "$runGeCKO" "$workflowName" "$workflowPrefix" "$partition" "--jobs 20"
}


runTest(){
    local geckoPath="$1"
    local testDir="$2"
    local workflowName="$3"
    local workflowPrefix="$4"
    local partition="$5"

    runGeCKO=${geckoPath}/runGeCKO.sh
    
    cd "${testDir}"
    echo -e "\n"${testDir}":"
    sbatchRunGeckoTest "${runGeCKO}" "${workflowName}" "${workflowPrefix}" "${partition}"
    cdSilent -
}

countMotifsInPath(){
    path="$1"
    motifs="$2"
    nb_motifs=$(echo "$path" | grep -oE "${motifs}" | wc -l || true)
    echo "$nb_motifs"
}

getTestWorkflow(){
    local testDir="$1"
    local workflow
    for workflow in "${!workflows[@]}" ; do
        if grep -q "$workflow" <<< "$testDir" ; then
            echo "$workflow"
            return 0
        fi
    done
}



runTests(){
    local geckoPath="$1"
    local partition="$2"

    for testDir in "${testDirs[@]}"; do
        nb_motifs=$(countMotifsInPath "$testDir" "$workflowMotifs")
        if [ "$nb_motifs" == 1 ] ; then
            testWorkflow=$(getTestWorkflow "$testDir")
            read -r workflowName workflowPrefix <<< "${workflows[$testWorkflow]}"
            runTest "$geckoPath" "$testDir" "$workflowName" "$workflowPrefix" "$partition"
        else
            echo "Warning: ambiguous workflow type for ${testDir}. Skipping this test."
        fi
    done
}


# ---------- MAIN --------- #

sourceDependencies "$geckoPath"

setErrorExitMsg

importTestDirs "$dirsFile"

cleanOldFiles "$geckoPath" "$shouldCleanOutputs"

dlImageSylabs "library://ge2pop_gecko/gecko/gecko:${imageVersion}" "utils/singularity_image/GeCKO.sif"

runTests "$geckoPath" "$partition"


# declare -A testFolders
# testFolders["DataCleaning_main"]="${geckoPath}/DATA_CLEANING/EXAMPLE DataCleaning DC TRUE" # fourth element = whether the workflow's test folder has subfolders or not
# testFolders["ReadMapping_main"]="${geckoPath}/READ_MAPPING/EXAMPLE ReadMapping RM TRUE"
# testFolders["VariantCalling_main"]="${geckoPath}/VARIANT_CALLING/EXAMPLE VariantCalling VC FALSE"
# testFolders["VcfFiltering_main"]="${geckoPath}/VCF_FILTERING/EXAMPLE VcfFiltering VF FALSE"
# testFolders["VcfFiltering_debug"]="${debugTestsDir}/VCF_FILTERING VcfFiltering VF TRUE"
# testFolders["ReadMapping_debug"]="${debugTestsDir}/READ_MAPPING ReadMapping RM TRUE"






