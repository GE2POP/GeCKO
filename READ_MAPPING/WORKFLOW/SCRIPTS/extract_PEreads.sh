#!/bin/bash

### Version pour tester avec samtools sort -n au lieu de sort (PP)

#{scripts_dir}/extract_PEreads.sh --bam {input.bams} --sample {wildcards.base} --bed_file {input.bed} --output_dir {subbams_dir}


set -e -o pipefail


#### ARGUMENTS:

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    --bam)
    BAM="$2"
    shift # past argument
    shift # past value
    ;;
    --sample)
    SAMPLE="$2"
    shift # past argument
    shift # past value
    ;;
    --bed_file)
    BED_FILE="$2"
    shift # past argument
    shift # past value
    ;;
    --output_dir)
    OUTPUT_DIR="$2"
    shift # past argument
    shift # past value
    ;;
  esac
done

### Manage file and folder paths (if relative path change it to absolute path)

if [[ ! "$OUTPUT_DIR" = /* ]] ; then
  OUTPUT_DIR=$(readlink -f $OUTPUT_DIR) ;
fi
if [[ ! -z "$BED_FILE" && ! "$BED_FILE" = /* ]] ; then
  BED_FILE=$(readlink -f $BED_FILE) ;
fi
if [[ ! -z "$BAM" && ! "$BAM" = /* ]] ; then
  BAM=$(readlink -f $BAM) ;
fi

# clean intermediate files when the script exits
clean_intermediate_files() {
  rm ${OUTPUT_DIR}/${SAMPLE}*_PP* ${OUTPUT_DIR}/${SAMPLE}*_UP*
}
trap 'clean_intermediate_files' EXIT

#get reads that are mapped -F4 and unproperly paired (UP) -F2
samtools view -F4 -F2 -b ${BAM} > ${OUTPUT_DIR}/${SAMPLE}_UP.bam
samtools index -c ${OUTPUT_DIR}/${SAMPLE}_UP.bam

#get reads that are mapped -F4 and properly paired (PP) -f2
samtools view -F4 -f2 -b ${BAM} > ${OUTPUT_DIR}/${SAMPLE}_PP.bam
samtools index -c ${OUTPUT_DIR}/${SAMPLE}_PP.bam

#handle the UP reads
samtools view -L ${BED_FILE} -b ${OUTPUT_DIR}/${SAMPLE}_UP.bam > ${OUTPUT_DIR}/${SAMPLE}_UP_extract.bam
samtools sort -n ${OUTPUT_DIR}/${SAMPLE}_UP_extract.bam -o ${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted.bam ;
samtools fixmate -m ${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted.bam  ${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted_fixed.bam ;
picard SamToFastq -I ${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted_fixed.bam  -F ${OUTPUT_DIR}/${SAMPLE}_UP_extract.R1.fastq -F2 ${OUTPUT_DIR}/${SAMPLE}_UP_extract.R2.fastq -FU ${OUTPUT_DIR}/${SAMPLE}_UP_extract.U.fastq -VALIDATION_STRINGENCY SILENT

#handle the PP reads
echo -n ""> ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.bam
echo -n ""> ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.list
i=0
# If two reads are on different zone they will be placed in the U.fastq; placing them in R1 and R2 will otherwise lead to unproperly paired tag in the subref mapping
# extract R1 R2 and U for each zone provided in the bed file and concatenate those fastq files
while read line; do
  zone=$(echo $line | sed -e 's/\s/:/' | sed -e 's/\s/-/' | sed -e 's/\r//')
  samtools view -b ${OUTPUT_DIR}/${SAMPLE}_PP.bam $zone > ${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_${i}.bam
  echo ${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_${i}.bam >> ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.list
  i=$(expr $i + 1)
  if(( $i == 10 )); then
    # -c option to keep RG group (genotype name) unchanged; otherwise add a random suffix for each file to be merged
    samtools merge -c -p --no-PG ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_tmp.bam -b ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.list
    mv  ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_tmp.bam ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.bam
    rm  ${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_*.bam

    i=0
    echo ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.bam > ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.list
  fi
done < ${BED_FILE}
#handle last regions
if(( $i > 0 )); then
  samtools merge  -c -p --no-PG ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_tmp.bam -b ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.list
  mv  ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_tmp.bam ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.bam
  rm  ${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_*.bam
fi

# Dedup and fixmate
samtools sort -n ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.bam > ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted.bam
samtools view -H ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted.bam > ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted_uniq.sam
samtools view ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted.bam | uniq >> ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted_uniq.sam
samtools fixmate -m ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted_uniq.sam  ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_fixed.bam

# Transform the bam into fastq
picard SamToFastq -I ${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_fixed.bam -F ${OUTPUT_DIR}/${SAMPLE}_PP_extract_R1.fastq -F2 ${OUTPUT_DIR}/${SAMPLE}_PP_extract_R2.fastq -FU ${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq -VALIDATION_STRINGENCY SILENT


# If two reads are properly paired in different zone we will have to reads with the same name in U.fastq (/1 and /2 are lost by samtools -view extraction when done one zone at a time)
# we identify those problematic reads
awk 'NR%4==1' ${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq | sort | uniq -d | cut -c 2- > ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list


nb_dup=$(awk 'END{print NR}' ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list)


if (( ${nb_dup} > 0 )); then
  #remove them from the U fastq file
  awk '{ if(NR==FNR){exclude["@"$1]} else { if(FNR%4==1) { header=$1; if( header in exclude){} else{print $0; getline; print; getline; print; getline; print}}}}'  ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list ${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq > ${OUTPUT_DIR}/${SAMPLE}_PP_extract_U_nodup.fastq
  # and get the two corresponding reads with /1 and /2 restored
  samtools view -L ${BED_FILE} -N ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list -b ${BAM} > ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.bam
  samtools sort -n ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.bam -o ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted.bam
  samtools fixmate -m ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted.bam  ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted_fixed.bam
  picard SamToFastq -I ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted_fixed.bam  -F ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R1.fastq -F2 ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R2.fastq -FU ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.U.fastq -VALIDATION_STRINGENCY SILENT

  # merge fastq files containing PP_U read
  cat ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.U.fastq ${OUTPUT_DIR}/${SAMPLE}_PP_extract_U_nodup.fastq ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R1.fastq ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R2.fastq > ${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq
  rm ${OUTPUT_DIR}/${SAMPLE}_PP_U_dup*
fi


# merge PP and PU and zip them
for type in R1 R2 U; do
  cat ${OUTPUT_DIR}/${SAMPLE}_PP_extract_${type}.fastq ${OUTPUT_DIR}/${SAMPLE}_UP_extract.${type}.fastq >  ${OUTPUT_DIR}/${SAMPLE}_extract.${type}.fastq
  gzip ${OUTPUT_DIR}/${SAMPLE}_extract.${type}.fastq
done
