#!/usr/bin/env python

import pandas as pd
import os,sys
from itertools import compress

#singularity: "docker://condaforge/mambaforge"


####################   DEFINE CONFIG VARIABLES BASED ON CONFIG FILE   ####################

### Variables from config file
vcf_raw = config["VCF_FILE"]
MAX_RATIO_NA_PER_SAMPLE = config["MAX_RATIO_NA_PER_SAMPLE"]

### Define paths
path_to_snakefile = workflow.snakefile
snakefile_dir = path_to_snakefile.rsplit('/', 1)[0]
scripts_dir = snakefile_dir+"/SCRIPTS"
working_directory = os.getcwd()

### Define outputs subfolders
outputs_directory = working_directory+"/WORKFLOWS_OUTPUTS/VCF_FILTERING"
VCF_reports_dir = outputs_directory+"/REPORTS"

### PIPELINE ###

rule FinalTargets:
    input:
        VCF_reports_dir+"/VCF_filtering_report.html"


 # ----------------------------------------------------------------------------------------------- #


rule Filters_Locus:
    input:
        vcf_raw
    output:
        outputs_directory+"/01_Locus_Filtered.recode.vcf"
    conda:
        "ENVS/conda_tools.yml"
    params:
        config["LOCUS_FILTERS"]
    shell:
        "vcftools --gzvcf {input} {params} --recode --recode-INFO-all --out {outputs_directory}/01_Locus_Filtered"

rule Filter_samples:
    input:
        outputs_directory+"/01_Locus_Filtered.recode.vcf"
    output:
        out_imiss = temp(outputs_directory+"/SamplesFilter.imiss"),
        samples_to_remove = outputs_directory+"/samples_to_remove.list",
        SamplesLocus_Filtered = outputs_directory+"/02_SamplesLocus_Filtered.recode.vcf"
    conda:
        "ENVS/conda_tools.yml"
    params:
        config["MAX_RATIO_NA_PER_SAMPLE"]
    shell:
        "vcftools --vcf {input} --missing-indv --out {outputs_directory}/SamplesFilter;"
        "awk -v max_pc_NA={params} '{{if($5>max_pc_NA){{print $0}}}}' {output.out_imiss} | cut -f1 > {output.samples_to_remove};"
        "vcftools --vcf {input} --remove {output.samples_to_remove} --recode --recode-INFO-all --out {outputs_directory}/02_SamplesLocus_Filtered"

rule Calculate_PopGenStat:
    input:
        SamplesLocus_Filtered = outputs_directory+"/02_SamplesLocus_Filtered.recode.vcf",
        header = scripts_dir+"/vcf_extra_info_header.txt"
    output:
        outputs_directory+"/SamplesLocus_Filtered_withPopStat.recode.vcf"
    conda:
        "ENVS/conda_tools.yml"
    shell:
        "{scripts_dir}/add_popGenStat2VCF.sh {input.SamplesLocus_Filtered} {input.header} {output}"

rule Filters_PopGenStat:
    input:
        outputs_directory+"/SamplesLocus_Filtered_withPopStat.recode.vcf"
    output:
        outputs_directory+"/03_PopGenStatsSamplesLocus_Filtered.vcf"
    conda:
        "ENVS/conda_tools.yml"
    params:
        config["POPGENSTATS_FILTERS"]
    shell:
        "bgzip {input};"
        "tabix {input}.gz;"
        "bcftools filter -sFilterSmk -i '{params}' {input}.gz "
        "| bcftools view -f 'PASS' > {output};"

rule BuildStatReport:
    input:
        vcf_raw = vcf_raw,
        vcf_Locus_Filtered = outputs_directory+"/01_Locus_Filtered.recode.vcf",
        vcf_SamplesLocus_Filtered = outputs_directory+"/02_SamplesLocus_Filtered.recode.vcf",
        vcf_PopGenStatsSamplesLocus_Filtered = outputs_directory+"/03_PopGenStatsSamplesLocus_Filtered.vcf"
    output:
        VCF_reports_dir+"/00_variants_raw_vcf.stats",
        VCF_reports_dir+"/01_Locus_Filtered_vcf.stats",
        VCF_reports_dir+"/02_SamplesLocus_Filtered_vcf.stats",
        VCF_reports_dir+"/03_PopGenStatsSamplesLocus_Filtered_vcf.stats"
    conda:
        "ENVS/conda_tools.yml"
    shell:
        "bcftools stats {input.vcf_raw} > {VCF_reports_dir}/00_variants_raw_vcf.stats;"
        "bcftools stats {input.vcf_Locus_Filtered} > {VCF_reports_dir}/01_Locus_Filtered_vcf.stats;"
        "bcftools stats {input.vcf_SamplesLocus_Filtered} > {VCF_reports_dir}/02_SamplesLocus_Filtered_vcf.stats;"
        "bcftools stats {input.vcf_PopGenStatsSamplesLocus_Filtered} > {VCF_reports_dir}/03_PopGenStatsSamplesLocus_Filtered_vcf.stats"

rule BuildReport:
    input:
        VCF_reports_dir+"/00_variants_raw_vcf.stats",
        VCF_reports_dir+"/01_Locus_Filtered_vcf.stats",
        VCF_reports_dir+"/02_SamplesLocus_Filtered_vcf.stats",
        VCF_reports_dir+"/03_PopGenStatsSamplesLocus_Filtered_vcf.stats"
    output:
        VCF_reports_dir+"/VCF_filtering_report.html"
    conda:
        "ENVS/conda_tools.yml"
    shell:
        "multiqc {input} -c {scripts_dir}/config_multiQC_deleteRecode.yaml -o {VCF_reports_dir} -n VCF_filtering_report"