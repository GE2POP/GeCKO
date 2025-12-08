#!/bin/bash

set -e -o pipefail

vcf_input=$1
stats_tsv_output=$2
DP_tsv_output=$3
GT_tsv_output=$4
variants_pos_tsv_output=$5
contigs_lengths_tsv_output=$6
outdir=$7



# clean intermediate files when the script exits
clean_intermediate_files() {
  rm -f ${outdir}/tmp_variables
  rm -f $1"_sample.gz"
}
trap 'clean_intermediate_files' EXIT

# Write headers
echo -e "contig\tlength" > $contigs_lengths_tsv_output
echo -e "contig\tpos" > $variants_pos_tsv_output
echo -e "Contig\tPos\tQual" > $stats_tsv_output #will be overwritten if the input VCF file is not empty

# Write the lengths of the reference contigs
grep '##contig=<' $vcf_input | sed 's/##contig=<ID=//' | sed 's/,length=/\t/' | sed 's/>//' >> $contigs_lengths_tsv_output


# Stop here if the VCF is empty
if ! grep -v '#' $vcf_input ; then
  echo "WARNING: No polymorphisms found in the final VCF file!"
  touch $DP_tsv_output $GT_tsv_output
  exit
fi 

# Write the list of variants positions
grep -v '#' $vcf_input | cut -f1,2 >> $variants_pos_tsv_output


# if the file is very big, sample 100000 rows
nb_rows=$(grep -c -v '#' $vcf_input)
if [[ $nb_rows -gt 100000 ]] ; then
  grep '#' $vcf_input > ${vcf_input}_sample
  grep -v '#' $vcf_input | awk -v rows=$nb_rows 'BEGIN {srand()} {if (rand() <= 100000/rows) print $0}' >> ${vcf_input}_sample
  vcf_input=${vcf_input}_sample
fi

# list all variables from column 8
grep -v '#' $vcf_input | cut -f8 | tr ';' '\n' | cut -d '=' -f1 | sort | uniq > ${outdir}/tmp_variables
cat ${outdir}/tmp_variables | tr '\n' '\t' | sed 's/\t$//' | awk '{print "Contig\tPos\tQual\t"$0}' > $stats_tsv_output


# for every site retrieve the values for all variables (and mark it NA if the info is missing)
nvar=$(cat ${outdir}/tmp_variables | wc -l)
awk -v nvar=$nvar -F"\t|;" '{
  if (NR==FNR)
    {vars[NR]=$1}
  else {
    print $1"\t"$2"\t"$3 ;
    for(j=1;j<=nvar;j++){
      for(i=4;i<=NF;i++){
        if($i ~ "^"vars[j]"=") {sub(vars[j]"=","",$i); print $i; break} else if (i == NF){print "NA"}
      }
    }
  }
}' ${outdir}/tmp_variables <(grep -v '#' $vcf_input | cut -f1,2,6,8) | awk -v nvar=$nvar 'NR % (nvar+1) {printf("%s\t", $0); next} {print $0}' >> $stats_tsv_output

# Extract DP and GT values
bcftools query -f '%CHROM\t%POS[\t%DP]\n' ${vcf_input} > $DP_tsv_output
bcftools query -f '%CHROM\t%POS[\t%GT]\n' ${vcf_input} > $GT_tsv_output
