#!/bin/bash

# {scripts_dir}/extract_PEreads.sh --bam {input.bams} --sample {wildcards.base} --bed_file {input.bed} --output_dir {subbams_dir} --max_merge_inputs "$max_merge_inputs"


set -e -o pipefail


#### ARGUMENTS:

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    --bam)
    BAM="$2"
    shift
    shift
    ;;
    --sample)
    SAMPLE="$2"
    shift
    shift
    ;;
    --bed_file)
    BED_FILE="$2"
    shift
    shift
    ;;
    --output_dir)
    OUTPUT_DIR="$2"
    shift
    shift
    ;;
    --max_merge_inputs)
    MAX_MERGE_INPUTS="$2"
    shift
    shift
    ;;
  esac
done


### Manage file and folder paths (if relative path change it to absolute path)

if [[ ! "$OUTPUT_DIR" = /* ]] ; then
  OUTPUT_DIR=$(readlink -f "$OUTPUT_DIR") ;
fi
if [[ ! -z "$BED_FILE" && ! "$BED_FILE" = /* ]] ; then
  BED_FILE=$(readlink -f "$BED_FILE") ;
fi
if [[ ! -z "$BAM" && ! "$BAM" = /* ]] ; then
  BAM=$(readlink -f "$BAM") ;
fi


# Clean intermediate files when the script exits
clean_intermediate_files() {
  rm -f -- "${OUTPUT_DIR}/${SAMPLE}"*_PP* "${OUTPUT_DIR}/${SAMPLE}"*_UP*
}
trap 'clean_intermediate_files' EXIT


count_bams_in_list() {
  local list_file="$1"

  awk 'NF > 0 { count++ } END { print count + 0 }' "$list_file"
}


remove_bams_from_list() {
  local list_file="$1"
  local bam_file

  while IFS= read -r bam_file; do
    [[ -n "$bam_file" ]] && rm -f -- "$bam_file"
  done < "$list_file"
}


merge_bam_list() {
  local input_list="$1"
  local output_bam="$2"
  local n_inputs
  local only_bam

  n_inputs=$(count_bams_in_list "$input_list")

  if (( n_inputs == 1 )); then
    only_bam=$(awk 'NF > 0 { print; exit }' "$input_list")
    mv -f -- "$only_bam" "$output_bam"
  else
    samtools merge -c -p --no-PG "$output_bam" -b "$input_list"
  fi
}


reduce_bam_list_by_fan_in() {
  local input_list="$1"
  local output_bam="$2"
  local max_inputs="$3"
  local output_dir="$4"
  local prefix="$5"

  local current_list="$input_list"
  local next_list
  local chunk_list
  local chunk_bam
  local bam_file
  local n_inputs
  local level=0
  local chunk_id
  local chunk_size

  n_inputs=$(count_bams_in_list "$current_list")

  while (( n_inputs > max_inputs )); do
    next_list="${output_dir}/${prefix}_level_${level}.list"
    chunk_list="${output_dir}/${prefix}_level_${level}_chunk.list"

    : > "$next_list"
    : > "$chunk_list"

    chunk_id=0
    chunk_size=0

    while IFS= read -r bam_file; do
      [[ -z "$bam_file" ]] && continue

      printf '%s\n' "$bam_file" >> "$chunk_list"
      chunk_size=$(( chunk_size + 1 ))

      if (( chunk_size == max_inputs )); then
        chunk_bam="${output_dir}/${prefix}_level_${level}_chunk_${chunk_id}.bam"

        merge_bam_list "$chunk_list" "$chunk_bam"
        printf '%s\n' "$chunk_bam" >> "$next_list"

        remove_bams_from_list "$chunk_list"
        : > "$chunk_list"

        chunk_id=$(( chunk_id + 1 ))
        chunk_size=0
      fi
    done < "$current_list"

    if (( chunk_size > 0 )); then
      chunk_bam="${output_dir}/${prefix}_level_${level}_chunk_${chunk_id}.bam"

      merge_bam_list "$chunk_list" "$chunk_bam"
      printf '%s\n' "$chunk_bam" >> "$next_list"

      remove_bams_from_list "$chunk_list"
    fi

    current_list="$next_list"
    n_inputs=$(count_bams_in_list "$current_list")
    level=$(( level + 1 ))
  done

  merge_bam_list "$current_list" "$output_bam"
  remove_bams_from_list "$current_list"
}


#get reads that are mapped -F4 and unproperly paired (UP) -F2
samtools view -F4 -F2 -b "${BAM}" > "${OUTPUT_DIR}/${SAMPLE}_UP.bam"
samtools index -c "${OUTPUT_DIR}/${SAMPLE}_UP.bam"

#get reads that are mapped -F4 and properly paired (PP) -f2
samtools view -F4 -f2 -b "${BAM}" > "${OUTPUT_DIR}/${SAMPLE}_PP.bam"
samtools index -c "${OUTPUT_DIR}/${SAMPLE}_PP.bam"

#handle the UP reads
samtools view -L "${BED_FILE}" -b "${OUTPUT_DIR}/${SAMPLE}_UP.bam" > "${OUTPUT_DIR}/${SAMPLE}_UP_extract.bam"
samtools sort -n "${OUTPUT_DIR}/${SAMPLE}_UP_extract.bam" -o "${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted.bam" ;
samtools fixmate -m "${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted.bam"  "${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted_fixed.bam" ;
picard SamToFastq -I "${OUTPUT_DIR}/${SAMPLE}_UP_extract_sorted_fixed.bam"  -F "${OUTPUT_DIR}/${SAMPLE}_UP_extract.R1.fastq" -F2 "${OUTPUT_DIR}/${SAMPLE}_UP_extract.R2.fastq" -FU "${OUTPUT_DIR}/${SAMPLE}_UP_extract.U.fastq" -VALIDATION_STRINGENCY SILENT


#handle the PP reads
i=0
j=0

FINAL_BAM="${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.bam"
ZONE_LIST="${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_zone.list"
BATCH_LIST="${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_batch.list"

rm -f -- "${FINAL_BAM}"
: > "${ZONE_LIST}"
: > "${BATCH_LIST}"

# If two reads are on different zone they will be placed in the U.fastq; placing them in R1 and R2 will otherwise lead to unproperly paired tag in the subref mapping
# Extract PP reads one BED region at a time, then merge temporary BAMs using a hierarchical reduction. No samtools merge call receives more than MAX_MERGE_INPUTS inputs, which avoids "too many open files" errors on large BED files.
# This also avoids the old accumulator strategy, where an increasingly large BAM was repeatedly re-read and re-written.
while read line; do
  zone=$(echo "$line" | tr -d '\r' | awk '{print $1 ":" $2 "-" $3}')
  tmp_bam="${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_zone_${i}.bam"

  samtools view -b "${OUTPUT_DIR}/${SAMPLE}_PP.bam" "$zone" > "${tmp_bam}"

  echo "${tmp_bam}" >> "${ZONE_LIST}"
  i=$(( i + 1 ))

  if (( i == MAX_MERGE_INPUTS )); then
    batch_bam="${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_batch_${j}.bam"

    merge_bam_list "${ZONE_LIST}" "${batch_bam}"
    echo "${batch_bam}" >> "${BATCH_LIST}"

    remove_bams_from_list "${ZONE_LIST}"
    : > "${ZONE_LIST}"

    i=0
    j=$(( j + 1 ))
  fi
done < "${BED_FILE}"

#handle last regions
if (( i > 0 )); then
  batch_bam="${OUTPUT_DIR}/${SAMPLE}_PP_extract_tmp_batch_${j}.bam"

  merge_bam_list "${ZONE_LIST}" "${batch_bam}"
  echo "${batch_bam}" >> "${BATCH_LIST}"

  remove_bams_from_list "${ZONE_LIST}"
fi

reduce_bam_list_by_fan_in \
  "${BATCH_LIST}" \
  "${FINAL_BAM}" \
  "${MAX_MERGE_INPUTS}" \
  "${OUTPUT_DIR}" \
  "${SAMPLE}_PP_extract_tmp_reduce"


# Dedup and fixmate
samtools sort -n "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge.bam" > "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted.bam"
samtools view -H "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted.bam" > "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted_uniq.sam"
samtools view "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted.bam" | uniq >> "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted_uniq.sam"
samtools fixmate -m "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_nameSorted_uniq.sam"  "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_fixed.bam"

# Transform the bam into fastq
picard SamToFastq -I "${OUTPUT_DIR}/${SAMPLE}_PP_extract_merge_fixed.bam" -F "${OUTPUT_DIR}/${SAMPLE}_PP_extract_R1.fastq" -F2 "${OUTPUT_DIR}/${SAMPLE}_PP_extract_R2.fastq" -FU "${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq" -VALIDATION_STRINGENCY SILENT


# If two reads are properly paired in different zone we will have to reads with the same name in U.fastq (/1 and /2 are lost by samtools -view extraction when done one zone at a time)
# we identify those problematic reads
awk 'NR%4==1' "${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq" | sort | uniq -d | cut -c 2- > "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list"


nb_dup=$(awk 'END{print NR}' "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list")


if (( ${nb_dup} > 0 )); then
  #remove them from the U fastq file
  awk '{ if(NR==FNR){exclude["@"$1]} else { if(FNR%4==1) { header=$1; if( header in exclude){} else{print $0; getline; print; getline; print; getline; print}}}}'  "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list" "${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq" > "${OUTPUT_DIR}/${SAMPLE}_PP_extract_U_nodup.fastq"

  # and get the two corresponding reads with /1 and /2 restored
  samtools view -L "${BED_FILE}" -N "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.list" -b "${BAM}" > "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.bam"
  samtools sort -n "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.bam" -o "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted.bam"
  samtools fixmate -m "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted.bam"  "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted_fixed.bam"
  picard SamToFastq -I "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup_sorted_fixed.bam"  -F "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R1.fastq" -F2 "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R2.fastq" -FU "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.U.fastq" -VALIDATION_STRINGENCY SILENT

  # merge fastq files containing PP_U read
  cat "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.U.fastq" "${OUTPUT_DIR}/${SAMPLE}_PP_extract_U_nodup.fastq" "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R1.fastq" "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup.R2.fastq" > "${OUTPUT_DIR}/${SAMPLE}_PP_extract_U.fastq"
  rm -f -- "${OUTPUT_DIR}/${SAMPLE}_PP_U_dup"*
fi


# merge PP and PU and zip them
for type in R1 R2 U; do
  cat "${OUTPUT_DIR}/${SAMPLE}_PP_extract_${type}.fastq" "${OUTPUT_DIR}/${SAMPLE}_UP_extract.${type}.fastq" >  "${OUTPUT_DIR}/${SAMPLE}_extract.${type}.fastq"
  gzip "${OUTPUT_DIR}/${SAMPLE}_extract.${type}.fastq"
done
