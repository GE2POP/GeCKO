#!/usr/bin/env bash
set -eo pipefail

SingularityImageVersion=1.2.1

### v WRITE YOUR MODULE LOAD OR CONDA ACTIVATE HERE v ###

#module purge
#module load snakemake/7.32.4-conda
#module load singularity/3.6.3

### ^ WRITE YOUR MODULE LOAD OR CONDA ACTIVATE HERE ^ ###



### DEFAULT OPTIONS
JOBS="--jobs 1"
LATENCY_WAIT="--latency-wait 20"

### DEFAULT ACTION VALUES
HELP="FALSE"

### ARGUMENTS
POSITIONAL=()
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    --help)
    HELP="TRUE"
    shift # past argument
    ;;
    --workflow)
    WORKFLOW="$2"
    shift
    shift
    ;;
    --cluster-profile)
    CLUSTER_PROFILE="$2"
    shift
    shift
    ;;
    --config-file)
    CONFIG="$2"
    shift
    shift
    ;;
    --jobs)
    JOBS="--jobs $2"
    shift
    shift
    ;;
    --forceall)
    FORCEALL="--forceall"
    shift
    ;;
    --latency-wait)
    LATENCY_WAIT="--latency-wait $2"
    shift
    shift
    ;;
    --dryrun)
    DRYRUN="--dryrun"
    shift
    ;;
    --report)
    REPORT="--report $2"
    shift
    shift
    ;;
    --extra-snakemake-options)
    EXTRA_SNAKEMAKE_OPTIONS="$2"
    shift
    shift
    ;;
    -*)
    echo -e "\nWARNING: $1 option is unknown and will be ignored.\n"
    POSITIONAL+=("$1")
    shift
    ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
  esac
done
set -- "${POSITIONAL[@]}"



# --------------------------------------------------------------------------------------------------------------#

printAbsolutePath () {
  if [[ ! -z "$1" ]] ; then
    fileOrFolder_printAbsolutePath=$(readlink -f "$1") ;
    echo ${fileOrFolder_printAbsolutePath}
  else
    echo $1
  fi
}

# --------------------------------------------------------------------------------------------------------------#


### Paths

GeCKO_path=$(dirname $(printAbsolutePath "$0"))
checks_path="${GeCKO_path}/utils/launching"


# --------------------------------------------------------------------------------------------------------------#

### Functions

source "${checks_path}/launching_utils.sh"


# --------------------------------------------------------------------------------------------------------------#


### Check if launcher_files folder exists
checkMissingDir $checks_path "GeCKOdir"


### Check if Singularity/Apptainer and Snakemake are available
isAvailable "Snakemake" "snakemake"
isAvailable "Singularity/Apptainer" "singularity"


### Download the singularity container if it can't be found
GeCKO_sif="${GeCKO_path}/utils/singularity_image/GeCKO.sif"
dlImageSylabs "library://ge2pop_gecko/gecko/gecko:${SingularityImageVersion}" "${GeCKO_sif}"


### Make scripts executable
for script in $(ls ${checks_path}/*.sh) ; do
  makeExecutable $script
done



### Print the help
if [ "${HELP}" = "TRUE" ] ; then
  cat ${checks_path}/launcher_help.txt
  exit 0
fi


### Check variables and paths
source "${checks_path}/allWorkflowsCheck.sh"
if [[ -f "${checks_path}/${WORKFLOW}Check.sh" ]] ; then
  source "${checks_path}/${WORKFLOW}Check.sh"
fi



### Unlock in case the folder is locked
snakemake --snakefile ${workflow_path}/${WORKFLOW_SMK} $JOBS --unlock --configfile ${CONFIG}



### RUN THE WORKFLOW
snakemake_command="snakemake --snakefile ${workflow_path}/${WORKFLOW_SMK} --printshellcmds $FORCEALL $DRYRUN $REPORT $LATENCY_WAIT $JOBS --use-singularity --configfile ${CONFIG} ${PROFILE} --config configfile_name=${CONFIG} clusterprofile_name=${PROFILE_FILE} ${EXTRA_SNAKEMAKE_OPTIONS} --singularity-args \"--bind ${GeCKO_path} --bind $(pwd) --bind ${HOME}\""
echo -e "\nCalling Snakemake:"
echo -e $snakemake_command"\n"
eval $snakemake_command
exit 0
