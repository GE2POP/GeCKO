#!/bin/bash



########### MAIN ##########

## Input data (BAMS_LIST, REFERENCE, GENOMIC_REFERENCE_CHR_SIZE) ##

# **BAMS_LIST**
checkMissingValue "$BAMS_LIST" "$(echo \$BAMS_LIST | sed 's/\$//')" "$VC_BAMS_LIST_msg"

checkMissingFile "$BAMS_LIST" "$(echo \$BAMS_LIST | sed 's/\$//')"


# **REFERENCE**
checkMissingValue "$REFERENCE" "$(echo \$REFERENCE | sed 's/\$//')"

checkMissingFile "$REFERENCE" "$(echo \$REFERENCE | sed 's/\$//')"

checkExtension "$REFERENCE" "$(echo \$REFERENCE | sed 's/\$//')" "fasta" "${fasta_ext[@]}"


# **GENOMIC_REFERENCE_CHR_SIZE**
checkMissingFile "$GENOMIC_REFERENCE_CHR_SIZE" "$(echo \$GENOMIC_REFERENCE_CHR_SIZE | sed 's/\$//')"

