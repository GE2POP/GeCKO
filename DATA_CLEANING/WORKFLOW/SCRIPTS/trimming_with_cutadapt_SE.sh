#!/usr/bin/env bash

set -e -o pipefail

#---------------------------------------------------#
#													#
#    	   	trimming_with_cutadapt_SE.sh	   		#
#													#
#---------------------------------------------------#

# >>> USAGE CONTEXT:
# github: https://github.com/BioInfo-GE2POP-BLE/CAPTURE_PIPELINES_SNAKEMAKE
# This script is intended to be used by the Snakemake workflow "DATA_CLEANING" / Sequencing type: Single end
# tools: Cutadapt (DOI:10.14806/ej.17.1.200)

# >>> OBJECTIVE(S):
# Trimming fastq file to remove adapters sequences, low quality sequences et short sequences

# >>> LAUNCHING EXAMPLE AND SETTINGS:
#./trimming_with_cutadapt.sh --trimdir {working_directory}/DEMULT_TRIM --sample sampleX --R sampleX.fastq.gz --adapter_file adapter_file_DEV.txt --quality_cutoff 30 --minimum_length 36 --cutadapt_trimming_extra_options

#--trimdir
	# storage space created by the workflow for the outputs of the trimming step: >>> {OUTPUTS_DIRNAME}/DATA_CLEANING/DEMULT_TRIM
#--sample
	# sample name
#--R
	# path to fastq.gz file corresponding to the sequences by sample (after demultiplexing)

#--adapter_file
	# path to the adapter_file.txt containing the list of samples names (column 1), sequences of adapter in the direction of read after the sequencing fragment (column 2)
	# example (no header, tab-separated):
	#Tc2208a	TGCGCTAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA
	#Tc2235a	GCTGAGAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA
	#Tc2249a	GATCTAAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA
#--quality_cutoff
	# parameter can be used to trim low-quality ends from reads. exemple: --quality_cutoff 30 > replacement of nucleotides by N if the quality is lower than Q30 (1 chance out of 30 that the base is wrong)
#--minimum_length
	# parameter to indicate the minimum size of the sequences to be kept.
#--cutadapt_trimming_extra_options
	# parameter to indicate other parameters to cutadapt. by example: number of cores to be allocated on cluster (--cores)

# >>> OUTPUTS
# one file by sample contain sequences demultiplexed : sample_trimmed.fastq.gz >>> storage in: {OUTPUTS_DIRNAME}/DATA_CLEANING/DEMULT_TRIM
# a report per sample, created automatically by Cutadap : trimming_cutadapt_sampleX.info >>> storage in: {OUTPUTS_DIRNAME}/DATA_CLEANING/DEMULT_TRIM/REPORTS/CUTADAPT_INFOS

#### ARGUMENTS:

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
  --adapter_file)
  ADAPTERS_SEQ_FILE="$2"
  shift # past argument
  shift # past value
  ;;
  --sample)
  SAMPLE="$2"
  shift # past argument
  shift # past value
  ;;
  --trimdir)
  TRIM_DIR="$2"
  shift # past argument
  shift # past value
  ;;
  --R)
  R_DEMULT="$2"
  shift # past argument
  shift # past value
  ;;
  --quality_cutoff)
  QUALITY_CUTOFF="$2"
  shift # past argument
  shift # past value
  ;;
  --minimum_length)
  MINIMUM_LENGTH="$2"
  shift # past argument
  shift # past value
  ;;
  --cutadapt_trimming_extra_options)
  CUTADAPT_TRIMMING_EXTRA_OPTIONS="$2"
  shift # past argument
  shift # past value
  ;;
  *)    				# unknown option
  POSITIONAL+=("$1") 	# save it in an array for later
  shift 				# past argument
  ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


# Manage file and folder paths (if relative path change it to absolute path)

if [[ ! "$ADAPTERS_SEQ_FILE" = /* ]] ; then
  ADAPTERS_SEQ_FILE=$(readlink -f $ADAPTERS_SEQ_FILE) ;
fi

if [[ ! "$TRIM_DIR" = /* ]] ; then
  TRIM_DIR=$(readlink -f $TRIM_DIR) ;
fi

if [[ ! "$R_DEMULT" = /* ]] ; then
  R_DEMULT=$(readlink -f $R_DEMULT) ;
fi



#### SCRIPT

## 1/ RETRIEVE FILES AND SEQUENCES
R_readthrough_seq=$(grep -w ${SAMPLE} ${ADAPTERS_SEQ_FILE} | cut -f2)

## 2/ RUN CUTADAPT - TRIMMING
cutadapt --action=trim --quality-cutoff ${QUALITY_CUTOFF} --minimum-length ${MINIMUM_LENGTH} ${CUTADAPT_TRIMMING_EXTRA_OPTIONS} -a ${R_readthrough_seq} -o ${TRIM_DIR}/${SAMPLE}.fastq.gz ${R_DEMULT} > ${TRIM_DIR}/trimming_cutadapt_${SAMPLE}.info
