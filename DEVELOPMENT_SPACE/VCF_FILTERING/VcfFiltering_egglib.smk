#!/usr/bin/env python

import pandas as pd
import os,sys
from itertools import compress

#singularity: "docker://condaforge/mambaforge"


####################   DEFINE CONFIG VARIABLES BASED ON CONFIG FILE   ####################

### Variables from config file
vcf_raw = config["VCF_FILE"]

bed_file = config["BED_FILE"]  ### >>>  /!\ facultatif si extraction et si besoin de faire tourner Egglib pour les stats finales
#bed_file = ""
#if (len(config["BED_FILE"]) > 0):
#    bed_file = config["BED_FILE"] # "/"+config[] ???

labels_file = config["LABELS_FILE"]  ### >>>  /!\ facultatif si besoin de faire tourner Egglib pour les stats finales
#labels_file = ""
#if (len(config["LABELS_FILE"]) > 0):
#    labels_file = config["LABELS_FILE"] # "/"+config[] ???


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
        VCF_reports_dir+"/multiQC_VcfFiltering_report.html",
        outputs_directory+"/workflow_info.txt"


 # ----------------------------------------------------------------------------------------------- #


rule Filter_Loci:
    input:
        vcf_raw
    output:
        outputs_directory+"/01_Locus_Filtered.recode.vcf",
        temp(outputs_directory+"/tmp_Locus_Filtered.recode.vcf")
    conda:
        "ENVS/conda_tools.yml"
    params:
        config["VCFTOOLS_LOCUS_FILTERING_OPTIONS"]
    shell:
        "vcftools --gzvcf {input} {params} --recode --recode-INFO-all --out {outputs_directory}/tmp_Locus_Filtered;"
        "grep '#' {outputs_directory}/tmp_Locus_Filtered.recode.vcf > {outputs_directory}/01_Locus_Filtered.recode.vcf;"
        "grep -v '#' {outputs_directory}/tmp_Locus_Filtered.recode.vcf | sort -k1,1 -k2,2n >> {outputs_directory}/01_Locus_Filtered.recode.vcf"


rule Filter_Samples:
    input:
        outputs_directory+"/01_Locus_Filtered.recode.vcf"
    output:
        out_imiss = temp(outputs_directory+"/SampleFilter.imiss"),
        samples_to_remove = outputs_directory+"/samples_to_remove.list",
        SampleLocus_Filtered = outputs_directory+"/02_SampleLocus_Filtered.recode.vcf"
    conda:
        "ENVS/conda_tools.yml"
    params:
        config["MAX_RATIO_NA_PER_SAMPLE"]
    shell:
        "vcftools --vcf {input} --missing-indv --out {outputs_directory}/SampleFilter;"
        "awk -v max_pc_NA={params} '{{if($5>max_pc_NA){{print $0}}}}' {output.out_imiss} | cut -f1 > {output.samples_to_remove};"
        "vcftools --vcf {input} --remove {output.samples_to_remove} --recode --recode-INFO-all --out {outputs_directory}/02_SampleLocus_Filtered"

rule Calculate_PopGenStats:
    input:
        SampleLocus_Filtered = outputs_directory+"/02_SampleLocus_Filtered.recode.vcf",
        header = scripts_dir+"/vcf_extra_info_header.txt"
    output:
        outputs_directory+"/SampleLocus_Filtered_withPopStats.recode.vcf"
    conda:
        "ENVS/conda_tools.yml"
    shell:
        "{scripts_dir}/add_popGenStats2VCF.sh {input.SampleLocus_Filtered} {input.header} {output}"

rule Filter_PopGenStats:
    input:
        outputs_directory+"/SampleLocus_Filtered_withPopStats.recode.vcf"
    output:
        outputs_directory+"/03_PopGenStatsSampleLocus_Filtered.vcf"
    conda:
        "ENVS/conda_tools.yml"
    params:
        config["POPGENSTATS_FILTERING_OPTIONS"]
    shell:
        "bgzip {input};"
        "tabix {input}.gz --csi;"
        "bcftools filter -sFilterSmk -i '{params}' {input}.gz "
        "| bcftools view -f 'PASS' > {output};"

rule Build_StatsReports:
    input:
        vcf_raw = vcf_raw,
        vcf_Locus_Filtered = outputs_directory+"/01_Locus_Filtered.recode.vcf",
        vcf_SampleLocus_Filtered = outputs_directory+"/02_SampleLocus_Filtered.recode.vcf",
        vcf_PopGenStatsSampleLocus_Filtered = outputs_directory+"/03_PopGenStatsSampleLocus_Filtered.vcf"
    output:
        VCF_reports_dir+"/00_variants_raw_vcf.stats",
        VCF_reports_dir+"/01_Locus_Filtered_vcf.stats",
        VCF_reports_dir+"/02_SampleLocus_Filtered_vcf.stats",
        VCF_reports_dir+"/03_PopGenStatsSampleLocus_Filtered_vcf.stats"
    conda:
        "ENVS/conda_tools.yml"
    shell:
        "bcftools stats {input.vcf_raw} > {VCF_reports_dir}/00_variants_raw_vcf.stats;"
        "bcftools stats {input.vcf_Locus_Filtered} > {VCF_reports_dir}/01_Locus_Filtered_vcf.stats;"
        "bcftools stats {input.vcf_SampleLocus_Filtered} > {VCF_reports_dir}/02_SampleLocus_Filtered_vcf.stats;"
        "bcftools stats {input.vcf_PopGenStatsSampleLocus_Filtered} > {VCF_reports_dir}/03_PopGenStatsSampleLocus_Filtered_vcf.stats"

rule Build_Report:
    input:
        VCF_reports_dir+"/00_variants_raw_vcf.stats",
        VCF_reports_dir+"/01_Locus_Filtered_vcf.stats",
        VCF_reports_dir+"/02_SampleLocus_Filtered_vcf.stats",
        VCF_reports_dir+"/03_PopGenStatsSampleLocus_Filtered_vcf.stats"
    output:
        VCF_reports_dir+"/multiQC_VcfFiltering_report.html"
    conda:
        "ENVS/conda_tools.yml"
    shell:
        "multiqc {input} -c {scripts_dir}/config_multiQC_deleteRecode.yaml -o {VCF_reports_dir} -n multiQC_VcfFiltering_report"


rule Calculate_EgglibStats:
    input:
        bed_file = bed_file
        labels_file = labels_file
        vcf_file = VCF_reports_dir+"/03_PopGenStatsSampleLocus_Filtered_vcf.stats"
    output:
        VCF_reports_dir+"/egglib_stats.txt"
        VCF_reports_dir+"/egglib_stats_pairwise.txt"
        VCF_reports_dir+"/egglib_outliers.txt"
    conda:
        "ENVS/conda_tools.yml"
    shell:
        "python3 {scripts_dir}/egglib_vcf_stats.py --bed_file {input.bed_file} --vcf_file {input.vcf_file} --labels_file {input.labels_file}"


rule Metadata:
    output:
        outputs_directory+"/workflow_info.txt"
    shell:
        "echo -e \"Date and time:\" > {outputs_directory}/workflow_info.txt;"
        "Date=$(date);"
        "echo -e \"${{Date}}\\n\" >> {outputs_directory}/workflow_info.txt;"
        "echo -e \"Workflow:\" >> {outputs_directory}/workflow_info.txt;"
        "echo -e \"https://github.com/BioInfo-GE2POP-BLE/CAPTURE_SNAKEMAKE_WORKFLOWS/tree/main/VCF_FILTERING\\n\" >> {outputs_directory}/workflow_info.txt;"
        "echo -e \"Commit ID:\" >> {outputs_directory}/workflow_info.txt;"
        "cd {snakefile_dir};"
        "git rev-parse HEAD >> {outputs_directory}/workflow_info.txt"