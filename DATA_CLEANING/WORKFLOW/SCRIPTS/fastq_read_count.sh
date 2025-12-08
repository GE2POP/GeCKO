#!/usr/bin/env bash

set -e -o pipefail

#---------------------------------------------------#
#													#
#    	   		fastq_read_count_PE .sh	   				#
#													#
#---------------------------------------------------#

# >>> USAGE CONTEXT:
# github: https://github.com/BioInfo-GE2POP-BLE/CAPTURE_PIPELINES_SNAKEMAKE
# This script is intended to be used by the Snakemake workflow "DATA_CLEANING" / Sequencing type: Paired_end

# >>> OBJECTIVE(S):
# count reads in all fastq.gz files of folder

# >>> LAUNCHING EXAMPLE AND SETTINGS:
#./fastq_read_count.sh --fastq_dir {demult_dir} --output {demult_reports_dir}/fastq_read_count_demult.txt

#--fastq_dir
	# path to the folder containing the fastq.gz files for which to count reads/sequences
#--output
	# path to the file containing the read count results in the fastq.gz files

# >>> OUTPUTS
# a file containing the read count results in the fastq.gz files. example: Reads_Count_DemultTrim.txt >>> storage in: {OUTPUTS_DIRNAME}/DATA_CLEANING/DEMULT_TRIM/REPORTS


#### ARGUMENTS:

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --fastq_dir)
    FASTQ_DIR="$2"
    shift # past argument
    shift # past value
    ;;
	--output)
    OUTPUT="$2"
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    				# unknown option
    POSITIONAL+=("$1") 	# save it in an array for later
    shift 				# past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


# Manage file and folder paths (if relative path change it to absolute path)

if [[ ! "$FASTQ_DIR" = /* ]] ; then
  FASTQ_DIR=$(readlink -f $FASTQ_DIR) ;
fi
if [[ ! "$OUTPUT" = /* ]] ; then
  OUTPUT=$(readlink -f $OUTPUT) ;
fi


#### SCRIPT:

for gz in ${FASTQ_DIR}/*fastq.gz ; do rows=$(gunzip -c $gz | wc -l) ; reads=$((rows/4)) ; name=$(basename $gz) ; echo -e ${name}"\t"${reads} ; done | sort > ${OUTPUT}
