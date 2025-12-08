#!/usr/bin/env bash

set -e -o pipefail

#---------------------------------------------------#
#													#
#    	   	trimming_with_cutadapt_PE.sh	   		#
#													#
#---------------------------------------------------#

# >>> USAGE CONTEXT:
# github: https://github.com/BioInfo-GE2POP-BLE/CAPTURE_PIPELINES_SNAKEMAKE
# This script is intended to be used by the Snakemake workflow "DATA_CLEANING" / Sequencing type: Paired end
# tools: Cutadapt (DOI:10.14806/ej.17.1.200)

# >>> OBJECTIVE(S):
# Trimming a pair of fastq files (R1 + R2 ) to remove adapters sequences, low quality sequences et short sequences

# >>> LAUNCHING EXAMPLE AND SETTINGS:
#./trimming_with_cutadapt.sh --trimdir {working_directory}/DEMULT_TRIM --sample sampleX --R1 sampleX.R1.fastq.gz --R2 sampleX.R2.fastq.gz --adapter_file adapter_file_DEV.txt --quality_cutoff 30 --minimum_length 36 --cutadapt_trimming_extra_options

#--trimdir
	# storage space created by the workflow for the outputs of the trimming step: >>> {OUTPUTS_DIRNAME}/DATA_CLEANING/DEMULT_TRIM
#--sample
	# sample name
#--R1
	# path to fastq.gz files corresponding to the R1 sequences by sample (after demultiplexing)
#--R2
	# path to fastq.gz files corresponding to the R2 sequences by sample (after demultiplexing)
#--adapter_file
	# path to the adapter_file.txt containing the list of samples names (column 1), sequences of adapter in the direction of read 1 after the sequencing fragment (column 2) and sequences of adapter in the direction of read 2 after the sequencing fragment (column 3)
	# example (no header, tab-separated):
	#Tc2208a	TGCGCTAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA	TGCGCTAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTGGCCGTATCATTA
	#Tc2235a	GCTGAGAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA	GCTGAGAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTGGCCGTATCATTA
	#Tc2249a	GATCTAAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA	GATCTAAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTGGCCGTATCATTA
#--quality_cutoff
	# parameter can be used to trim low-quality ends from reads. exemple: --quality_cutoff 30 > replacement of nucleotides by N if the quality is lower than Q30 (1 chance out of 30 that the base is wrong)
#--minimum_length
	# parameter to indicate the minimum size of the sequences to be kept.
#--cutadapt_trimming_extra_options
	# parameter to indicate other parameters to cutadapt. by example: number of cores to be allocated on cluster (--cores)
	


# >>> OUTPUTS
# two files by sample contain sequences demultiplexed : sample_trimmed.R1.fastq.gz and sample_trimmed.R2.fastq.gz >>> storage in: {OUTPUTS_DIRNAME}/DATA_CLEANING/DEMULT_TRIM
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
  --R1)
  R1_DEMULT="$2"
  shift # past argument
  shift # past value
  ;;
  --R2)
  R2_DEMULT="$2"
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

if [[ ! "$R1_DEMULT" = /* ]] ; then
  R1_DEMULT=$(readlink -f $R1_DEMULT) ;
fi

if [[ ! "$R2_DEMULT" = /* ]] ; then
  R2_DEMULT=$(readlink -f $R2_DEMULT) ;
fi



#### SCRIPT

## 1/ RETRIEVE FILES AND SEQUENCES
R1_readthrough_seq=$(grep -w ${SAMPLE} ${ADAPTERS_SEQ_FILE} | cut -f2)
R2_readthrough_seq=$(grep -w ${SAMPLE} ${ADAPTERS_SEQ_FILE} | cut -f3)

## 2/ RUN CUTADAPT - TRIMMING
cutadapt --action=trim --quality-cutoff ${QUALITY_CUTOFF} --minimum-length ${MINIMUM_LENGTH} ${CUTADAPT_TRIMMING_EXTRA_OPTIONS} -a ${R1_readthrough_seq} -A ${R2_readthrough_seq} -o ${TRIM_DIR}/${SAMPLE}.R1.fastq.gz -p ${TRIM_DIR}/${SAMPLE}.R2.fastq.gz ${R1_DEMULT} ${R2_DEMULT} > ${TRIM_DIR}/trimming_cutadapt_${SAMPLE}.info
