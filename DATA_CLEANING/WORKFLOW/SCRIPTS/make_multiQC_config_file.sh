#!/bin/bash

set -e -o pipefail

#{scripts_dir}/make_multiQC_config_file.sh --config_file_base {scripts_dir}/config_multiQC_classic.yaml --nb_reads ${{mean_nb_reads}} --output_dir {demult_reports_dir}

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
  --config_file_base)
  CONFIG_FILE_BASE="$2"
  shift # past argument
  shift
  ;;
  --nb_reads)
  NB_READS="$2"
  shift # past argument
  shift
  ;;
  --output_dir)
  OUTPUT_DIR="$2"
  shift
  shift
  ;;
  *)    				# unknown option
  POSITIONAL+=("$1") 	# save it in an array for later
  shift 				# past argument
  ;;
esac
done

cp $CONFIG_FILE_BASE ${OUTPUT_DIR}/config_multiQC.yaml

if [[ $NB_READS -lt 100000000 && $NB_READS -gt 100000 ]] ; then
  echo "read_count_multiplier: 0.001" >> ${OUTPUT_DIR}/config_multiQC.yaml
  echo "read_count_prefix: \"K\"" >> ${OUTPUT_DIR}/config_multiQC.yaml
  echo "read_count_desc: \"thousands\"" >> ${OUTPUT_DIR}/config_multiQC.yaml
elif [[ $NB_READS -lt 100000 ]] ; then
  echo "read_count_multiplier: 1" >> ${OUTPUT_DIR}/config_multiQC.yaml
  echo "read_count_prefix: \"\"" >> ${OUTPUT_DIR}/config_multiQC.yaml
  echo "read_count_desc: \"\"" >> ${OUTPUT_DIR}/config_multiQC.yaml
fi
