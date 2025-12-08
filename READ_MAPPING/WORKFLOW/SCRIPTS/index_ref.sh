#!/bin/bash

#./index_ref.sh {input.ref} {mapper}

set -e -o pipefail

REF=$1
MAPPER=$2

# Index reference
if [[ "$MAPPER" == "bwa-mem2_mem" ]] ; then
  bwa-mem2 index $REF
fi

if [[ "$MAPPER" == "bwa_mem" ]] ; then
  bwa index $REF
fi

if [[ "$MAPPER" == "bowtie2" ]] ; then
  REF_INDEX=$(echo $REF | sed 's/.fasta//' | sed 's/.fas//' | sed 's/.fa//')
  bowtie2-build $REF $REF_INDEX
fi

if [[ "$MAPPER" == "minimap2" ]] ; then
  REF_INDEX=$(echo $REF | sed 's/.fasta/.mmi/' | sed 's/.fas//' | sed 's/.fa/.mmi/')
  minimap2 -d $REF_INDEX $REF
fi
