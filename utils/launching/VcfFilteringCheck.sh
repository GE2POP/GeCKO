#!/bin/bash


########### MAIN ##########


## INPUT FILES

checkMissingValue "$VCF_FILE" "$(echo \$VCF_FILE | sed 's/\$//')"

checkMissingFile "$VCF_FILE" "$(echo \$VCF_FILE | sed 's/\$//')"

checkExtension "$VCF_FILE" "$(echo \$VCF_FILE | sed 's/\$//')" "vcf" "${vcf_ext[@]}"


### VCF FILTERING PARAMETERS ###

checkMissingValue "$MAX_NA_PER_SAMPLE" "$(echo \$MAX_NA_PER_SAMPLE | sed 's/\$//')"

