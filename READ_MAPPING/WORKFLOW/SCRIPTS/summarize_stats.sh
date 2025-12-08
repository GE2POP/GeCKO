#!/bin/bash

set -e -o pipefail


while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    --stats_folder)
    STATS_FOLDER="$2"
    shift
    shift
    ;;
    --bams_folder)
    BAMS_FOLDER="$2"
    shift
    shift
    ;;
    --rmdup)
    RM_DUP="$2"
    shift
    shift
    ;;
    --umi)
    UMI="$2"
    shift # past argument
    shift # past value
    ;;
    --output)
    OUTPUT="$2"
    shift
    shift
    ;;
  esac
done

dup_fields=""
if [[ "$RM_DUP" = "TRUE" || "$UMI" = "TRUE" ]] ; then
  dup_fields="\tReads_mapped_without_dup\t%_reads_mapped_without_dup"
fi

echo -e "Sample\tTotal_seqs\tReads_mapped\t%_reads_mapped${dup_fields}\tReads_mapped_after_filtering\t%_reads_mapped_after_filtering" > $OUTPUT


for MarkedDup_stats_file in $(ls $STATS_FOLDER/stats_*) ; do
  sample=$(basename $MarkedDup_stats_file | sed 's/stats_//')
  filtered_bam="${BAMS_FOLDER}/${sample}.bam"
  reads_mapped=$(cat $MarkedDup_stats_file | grep 'reads mapped:' | cut -f3)
  total_reads=$(cat $MarkedDup_stats_file | grep 'raw total sequences:' | cut -f3)
  if [[ $total_reads -eq 0 ]] ; then
    prc_mapped="NA"
  else
    prc_mapped=$(echo "scale=2; 100*$reads_mapped/$total_reads" | bc -l)
  fi
  reads_mapped_filt=$(samtools view -c -F 2308 $filtered_bam)

  if [[ "$RM_DUP" = "TRUE" ]] ; then
    rm_dup_bam="${BAMS_FOLDER}/${sample}_rmDup.bam"
  elif [[ "$UMI" = "TRUE" ]] ; then
    rm_dup_bam="${BAMS_FOLDER}/${sample}_UMIdedup.bam"
  fi

  if [[ "$RM_DUP" = "TRUE" || "$UMI" = "TRUE" ]] ; then
    reads_mapped_rmDup=$(samtools view -c -F 2308 $rm_dup_bam)
    if [[ $total_reads -eq 0 ]] ; then
      prc_rmDup_mapped="NA"
      prc_filt_mapped="NA"
    else
      prc_rmDup_mapped=$(echo "scale=2; 100*$reads_mapped_rmDup/$reads_mapped" | bc -l)
      prc_filt_mapped=$(echo "scale=2; 100*$reads_mapped_filt/$reads_mapped_rmDup" | bc -l)
    fi
    echo -e $sample"\t"$total_reads"\t"$reads_mapped"\t"$prc_mapped"\t"$reads_mapped_rmDup"\t"$prc_rmDup_mapped"\t"$reads_mapped_filt"\t"$prc_filt_mapped >> $OUTPUT
  elif [[ "$RM_DUP" = "FALSE" && "$UMI" = "FALSE" ]] ; then
    if [[ $total_reads -eq 0 ]] ; then
      prc_filt_mapped="NA"
    else
      prc_filt_mapped=$(echo "scale=2; 100*$reads_mapped_filt/$reads_mapped" | bc -l)
    fi
    echo -e $sample"\t"$total_reads"\t"$reads_mapped"\t"$prc_mapped"\t"$reads_mapped_filt"\t"$prc_filt_mapped >> $OUTPUT
  fi
done
