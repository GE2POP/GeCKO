#!/usr/bin/env python

import os,sys,glob
from itertools import compress
from datetime import datetime

default_threads = 1 #this will be erased by the user's specifications for each rule in the profile yaml

WF="READ_MAPPING"

####################   DEFINE CONFIG VARIABLES BASED ON CONFIG FILE   ####################

### Define paths
path_to_snakefile = workflow.snakefile
snakefile_dir = path_to_snakefile.rsplit('/', 1)[0]
scripts_dir = snakefile_dir+"/SCRIPTS"
working_directory = os.getcwd()

### Variables from config file
paired_end = config["PAIRED_END"]
trim_dirs = list(config["TRIM_DIRS"].split(" "))

if (len(config["TRIM_DIRS"]) == 0):
    trim_dirs = [f"WORKFLOWS_OUTPUTS/DATA_CLEANING/DEMULT_TRIM"]

if config["REMOVE_DUP_MARKDUPLICATES"]:
    rm_dup = "TRUE"
else:
    rm_dup = "FALSE"


if config["REMOVE_DUP_UMI"]:
    dedupUMI = "TRUE"
else:
    dedupUMI = "FALSE"

ref = os.path.abspath(config["REFERENCE"])
mapping_subfolder = ""
if (len(config["MAPPING_SUBFOLDER"]) > 0):
    mapping_subfolder = "/"+config["MAPPING_SUBFOLDER"]

ref_name = ref.rsplit('/', 1)[::-1][0].replace('.fasta','').replace('.fas','').replace('.fa','')

existing_bed = config["BED"]

if (len(config["BED_MIN_MEAN_COV"]) > 0):
    create_bed = True
else:
    create_bed = False

if (len(existing_bed) == 0 and len(config["BED_MIN_MEAN_COV"]) == 0):
    count_reads_zones = False
else:
    count_reads_zones = True


mapper = config["MAPPER"]


### Samples list
if paired_end:
    end="--pairedEnd"

    samples = []
    fastqs_list_dict = {}

    for trim_dir in trim_dirs:
        fastqs_R1_list = [fastq for fastq in os.listdir(trim_dir) if '.R1.fastq.gz' in fastq]

        fastqs_R2_list = []
        for fastq_R1 in fastqs_R1_list:
            fastq_R2 = fastq_R1.replace(".R1.", ".R2.")
            fastqs_R2_list.append(fastq_R2)
            sample = fastq_R1.replace(".R1.fastq.gz", "")
            samples.append(sample)
            fastqs_list_dict[sample] = [trim_dir+"/"+str(fastq_R1), trim_dir+"/"+str(fastq_R2)]

else:
    end="--singleEnd"

    samples = []
    fastqs_list_dict = {}

    for trim_dir in trim_dirs:
        fastqs_list = [fastq for fastq in os.listdir(trim_dir) if '.fastq.gz' in fastq]

        for fastq in fastqs_list:
            sample = fastq.replace(".fastq.gz", "")
            samples.append(sample)
            fastqs_list_dict[sample] = trim_dir+"/"+str(fastq)


### Define outputs subfolders
outputs_directory = f"{working_directory}/WORKFLOWS_OUTPUTS/{WF}"
mapping_dir = outputs_directory+mapping_subfolder
bams_dir = mapping_dir+"/BAMS"
bams_reports_dir = bams_dir+"/REPORTS"
bams_stats_reports_dir = bams_reports_dir+"/STATS"
zones_stats_dir = mapping_dir+"/ZONES_STATS"
subref_dir = mapping_dir+"/EXTRACTED_BAMS/REFERENCE_zones"
subbams_dir = mapping_dir+"/EXTRACTED_BAMS/BAMS_zones"
subbams_reports_dir = subbams_dir+"/REPORTS"
subbams_stats_reports_dir = subbams_reports_dir+"/STATS"

### If the bed file needs to be generated
bed_to_create = subref_dir+"/auto_zones.bed"
clean_bed = subref_dir+"/user_clean.bed"

### Expected reference index
if (mapper == "bwa-mem2_mem"):
    ref_index=ref+".bwt.2bit.64"

if (mapper == "bwa_mem"):
    ref_index=ref+".bwt"

if (mapper == "bowtie2"):
    ref_base=ref.replace(".fasta","").replace(".fas","").replace(".fa","")
    ref_index=ref_base+".1.bt2"

if mapper == "minimap2":
    ref_base=ref.replace(".fasta","").replace(".fas","").replace(".fa","")
    ref_index=ref_base+".mmi"


### Generate the workflow_info name
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
workflow_info_file = f"{mapping_dir}/workflow_info_{timestamp}.txt"

### Image path
GeCKO_image = os.path.abspath(os.path.join(snakefile_dir, "../../utils/singularity_image/GeCKO.sif"))


### FUNCTIONS
def buildExpectedFiles(filesNames, isExpected):
    expectedFiles = list(compress(filesNames, isExpected))
    return(expectedFiles)

def find_latest_info_file(directory):
    files = glob.glob(f"{directory}/workflow_info_*.txt")
    if not files:
        return ""
    latest_file = max(files, key=os.path.getctime)
    return latest_file


### PIPELINE ###
ruleorder: MarkDuplicates_Bams > Filter_Bams
ruleorder: DedupUMI_Bams > Filter_Bams
ruleorder: Mapping_PairedEndFastqs > Filter_Bams
ruleorder: Mapping_SingleEndFastqs > Filter_Bams
ruleorder: Stats_Bams > Filter_Bams
ruleorder: Remapping_PairedEndExtractedFastqs > Filter_Subbams
ruleorder: Remapping_SingleEndExtractedFastqs > Filter_Subbams
ruleorder: Stats_Subbams > Filter_Subbams


rule FinalTargets:
    input:
        mapping_dir+"/summary.sentinel"

# ------------------------------------------------------------------------------------------------------------- #



rule Index_Reference:
    input:
        ref
    output:
        ref_index
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "{scripts_dir}/index_ref.sh {input} {mapper}"


rule Mapping_PairedEndFastqs:
    input:
        fastq_paired_R1 = lambda wildcards: fastqs_list_dict[wildcards.base][0],
        fastq_paired_R2 = lambda wildcards: fastqs_list_dict[wildcards.base][1],
        ref = ref,
        ref_index = ref_index
    output:
        buildExpectedFiles([ temp(bams_dir+"/{base}_markedDup.bam"),
        temp(bams_dir+"/{base}_raw.sam"),
        temp(bams_dir+"/{base}_sortcoord.bam"),
        bams_reports_dir+"/DUPLICATES/{base}.bam.metrics" ],

        [ paired_end and not config["REMOVE_DUP_UMI"], paired_end, paired_end, paired_end and not config["REMOVE_DUP_UMI"] ])
    singularity:
        GeCKO_image
    threads: default_threads
    params:
        mapper = mapper,
        extra_mapper_options = config["EXTRA_MAPPER_OPTIONS"],
        technology = config["SEQUENCING_TECHNOLOGY"],
        picard_markduplicates_options = config["PICARD_MARKDUPLICATES_OPTIONS"],
        picard_markduplicates_java_options = config["PICARD_MARKDUPLICATES_JAVA_OPTIONS"]
    shell:
        "{scripts_dir}/mapping.sh --paired_end --fastq_R1 \"{input.fastq_paired_R1}\" --fastq_R2 \"{input.fastq_paired_R2}\" "
        "--ref {input.ref} --mapper {params.mapper} --mapper_options \"{params.extra_mapper_options}\" --technology \"{params.technology}\" "
        "--output_dir {bams_dir} --sample {wildcards.base} --MD_options \"{params.picard_markduplicates_options}\" "
        "--MD_java_options \"{params.picard_markduplicates_java_options}\" --reports_dir {bams_reports_dir} --umi {dedupUMI}"



rule Mapping_SingleEndFastqs:
    input:
        fastq_single = lambda wildcards: fastqs_list_dict[wildcards.base],
        ref = ref,
        ref_index = ref_index
    output:
        buildExpectedFiles([ temp(bams_dir+"/{base}_markedDup.bam"),
        temp(bams_dir+"/{base}_raw.sam"),
        temp(bams_dir+"/{base}_sortcoord.bam"),
        bams_reports_dir+"/DUPLICATES/{base}.bam.metrics" ],

        [ not paired_end and not config["REMOVE_DUP_UMI"], not paired_end, not paired_end, not paired_end and not config["REMOVE_DUP_UMI"] ])
    singularity:
        GeCKO_image
    threads: default_threads
    params:
        mapper = config["MAPPER"],
        extra_mapper_options = config["EXTRA_MAPPER_OPTIONS"],
        technology = config["SEQUENCING_TECHNOLOGY"],
        picard_markduplicates_options = config["PICARD_MARKDUPLICATES_OPTIONS"],
        picard_markduplicates_java_options = config["PICARD_MARKDUPLICATES_JAVA_OPTIONS"]
    shell:
        "{scripts_dir}/mapping.sh --single_end --fastq \"{input.fastq_single}\" "
        "--ref {input.ref} --mapper {params.mapper} --mapper_options \"{params.extra_mapper_options}\" --technology \"{params.technology}\" "
        "--output_dir {bams_dir} --sample {wildcards.base} --MD_options \"{params.picard_markduplicates_options}\" "
        "--MD_java_options \"{params.picard_markduplicates_java_options}\" --reports_dir {bams_reports_dir} --umi {dedupUMI}"


rule Stats_Bams:
    input:
        bams_dir+"/{base}_sortcoord.bam" if config["REMOVE_DUP_UMI"] else bams_dir+"/{base}_markedDup.bam"
    output:
        bams_stats_reports_dir+"/stats_{base}"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "samtools stats {input} > {output}"


rule MarkDuplicates_Bams:
    input:
        bams_dir+"/{base}_markedDup.bam"
    output:
        MD_bam = temp(bams_dir+"/{base}_rmDup.bam"),
        metrics = bams_reports_dir+"/DUPLICATES_TMP/{base}.bam.metrics"
    singularity:
        GeCKO_image
    params:
        picard_markduplicates_options = config["PICARD_MARKDUPLICATES_OPTIONS"],
        picard_markduplicates_java_options = config["PICARD_MARKDUPLICATES_JAVA_OPTIONS"]
    threads: default_threads
    shell:
        "picard {params.picard_markduplicates_java_options} MarkDuplicates -I {input} -O {output.MD_bam} -VALIDATION_STRINGENCY SILENT {params.picard_markduplicates_options} -REMOVE_DUPLICATES TRUE -M {output.metrics}"


rule DedupUMI_Bams:
    input:
        bams_dir+"/{base}_sortcoord.bam"
    output:
        csi = temp(bams_dir+"/{base}_sortcoord.bam.csi"),
        bam_dedup = temp(bams_dir+"/{base}_UMIdedup.bam")
    singularity:
        GeCKO_image
    params:
        samtools_index_options = config["SAMTOOLS_INDEX_OPTIONS"],
        umitools_dedup_options = config["UMITOOLS_DEDUP_OPTIONS"] + (" --paired" if paired_end else "")
    threads: default_threads
    shell:
        "samtools index -c {params.samtools_index_options} {input};"
        "umi_tools dedup --stdin={input} --stdout={output.bam_dedup} {params.umitools_dedup_options}"



rule Filter_Bams:
    input:
        bams_dir+"/{base}_UMIdedup.bam" if config["REMOVE_DUP_UMI"] else (bams_dir+"/{base}_rmDup.bam" if config["REMOVE_DUP_MARKDUPLICATES"] else bams_dir+"/{base}_markedDup.bam")
    output:
        bams_dir+"/{base}.bam"
    singularity:
        GeCKO_image
    params:
        samtools_view_filters = config["SAMTOOLS_VIEW_FILTERS1"]
    threads: default_threads
    shell:
        "samtools view -b {params.samtools_view_filters} -o {output} {input}"


rule Summarize_BamsReadsCount:
    input:
        buildExpectedFiles([
        expand("{bams_stats_reports_dir}/stats_{sample}", sample=samples, bams_stats_reports_dir=bams_stats_reports_dir),
        expand("{bams_dir}/{sample}_rmDup.bam", sample=samples, bams_dir=bams_dir),
        expand("{bams_dir}/{sample}_UMIdedup.bam", sample=samples, bams_dir=bams_dir),
        expand("{bams_dir}/{sample}.bam", sample=samples, bams_dir=bams_dir) ],

        [ True, config["REMOVE_DUP_MARKDUPLICATES"], config["REMOVE_DUP_UMI"], True ])
    output:
        bams_reports_dir+"/nb_reads_per_sample.tsv"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "{scripts_dir}/summarize_stats.sh --stats_folder {bams_stats_reports_dir} --bams_folder {bams_dir} --rmdup {rm_dup} --umi {dedupUMI} --output {output};"
        "rm -rf {bams_reports_dir}/DUPLICATES_TMP"


rule MultiQC_Bams:
    input:
        stats_files = expand("{bams_stats_reports_dir}/stats_{sample}", sample=samples, bams_stats_reports_dir=bams_stats_reports_dir)
    output:
        bams_reports_dir+"/multiQC_ReadMapping_Bams_Report.html"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "multiqc {input.stats_files} -c {scripts_dir}/config_multiQC_clean_names.yaml -o {bams_reports_dir} -n multiQC_ReadMapping_Bams_Report -i ReadMapping_Bams_Report -f"



rule Index_Bams:
    input:
        bam = bams_dir+"/{base}.bam"
    output:
        csi = bams_dir+"/{base}.bam.csi"
    singularity:
        GeCKO_image
    params:
        samtools_index_options = config["SAMTOOLS_INDEX_OPTIONS"]
    threads: default_threads
    shell:
        "samtools index -c {params.samtools_index_options} {input.bam}"


rule Create_BamsList:
    input:
        expand("{bams_dir}/{sample}.bam", sample=samples, bams_dir=bams_dir)
    output:
        mapping_dir+"/bams_list.txt"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "ls -d {bams_dir}/*.bam > {output}"


rule Clean_BedFile:
    input:
        existing_bed
    output:
        clean_bed
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        """
        bedtools sort -i {input} | bedtools merge -i - > {output}
        """


rule Create_BedFile:
    input:
        expand("{bams_dir}/{sample}.bam", sample=samples, bams_dir=bams_dir),
        expand("{bams_dir}/{sample}.bam.csi", sample=samples, bams_dir=bams_dir)
    output:
        bed_to_create
    singularity:
        GeCKO_image
    params:
        min_cov = float(config["BED_MIN_MEAN_COV"]) * len(expand("{bams_dir}/{sample}.bam", sample=samples, bams_dir=bams_dir)) if len(config["BED_MIN_MEAN_COV"]) > 0 else 0,
        min_dist = config["BED_MIN_DIST"],
        min_length = config["BED_MIN_LENGTH"]
    threads: default_threads
    shell:
        "{scripts_dir}/make_bed_file.sh --input_bams_dir {bams_dir} --output_dir {subref_dir} --min_cov {params.min_cov} --min_dist {params.min_dist} --min_length {params.min_length}"


rule CountReadsZones_Bams:
    input:
        bams = expand("{bams_dir}/{sample}.bam", sample=samples, bams_dir=bams_dir),
        csis = expand("{bams_dir}/{sample}.bam.csi", sample=samples, bams_dir=bams_dir),
        bed = bed_to_create if create_bed else clean_bed
    output:
        zones_stats_dir+"/mean_depth_per_zone_per_sample.tsv"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "echo ZONE {samples} | sed 's/ /\t/g' > {zones_stats_dir}/mean_depth_per_zone_per_sample.tsv ;"
        "samtools bedcov {input.bed} {input.bams} | awk '{{l=$3-$2+1; printf $1\"_\"$2\"_\"$3\"\t\"; for (i=4;i<NF;i++) printf $i/l\"\t\"; printf $NF/l\"\\n\"}}' >> {zones_stats_dir}/mean_depth_per_zone_per_sample.tsv"


rule Create_SubReference:
    input:
        ref = ref,
        bed = bed_to_create if create_bed else clean_bed
    output:
        subref = subref_dir+"/"+ref_name+"_zones.fasta",
        tmp_bed = temp(subref_dir+"/tmp_zones.bed")
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "awk '{{print $1\":\"$2\"-\"$3}}' {input.bed} > {output.tmp_bed} ;"
        "samtools faidx {input.ref} --region-file {output.tmp_bed} > {output.subref};"
        "sed -i 's/:/_/g ; s/-/_/g' {output.subref} ;"
        "{scripts_dir}/index_ref.sh {output.subref} {mapper}"


rule Extract_PairedEndReads:
    input:
        bams = bams_dir+"/{base}.bam",
        bed = bed_to_create if create_bed else clean_bed
    output:
        tmp_extracted_fastq_paired_R1 = temp(subbams_dir+"/{base}_extract.R1.fastq.gz"),
        tmp_extracted_fastq_paired_R2 = temp(subbams_dir+"/{base}_extract.R2.fastq.gz"),
        tmp_extracted_fastq_unpaired = temp(subbams_dir+"/{base}_extract.U.fastq.gz")
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        r"""
        max_merge_inputs=$(( $(ulimit -n) - 20 ))
        if (( max_merge_inputs > 512 )); then
          max_merge_inputs=512
        fi
        {scripts_dir}/extract_PEreads.sh --bam {input.bams} --sample {wildcards.base} --bed_file {input.bed} --output_dir {subbams_dir} --max_merge_inputs "$max_merge_inputs"
        """


rule Remapping_PairedEndExtractedFastqs:
    input:
        fastq_paired_R1 = subbams_dir+"/{base}_extract.R1.fastq.gz",
        fastq_paired_R2 = subbams_dir+"/{base}_extract.R2.fastq.gz",
        fastq_unpaired = subbams_dir+"/{base}_extract.U.fastq.gz",
        subref = subref_dir+"/"+ref_name+"_zones.fasta"
    output:
        buildExpectedFiles([ temp(subbams_dir+"/{base}_markedDup.bam"),
        temp(subbams_dir+"/{base}_paired.sam"),
        temp(subbams_dir+"/{base}_unpaired.sam"),
        temp(subbams_dir+"/{base}_raw.sam"),
        temp(subbams_dir+"/{base}_sortcoord.bam"),
        subbams_reports_dir+"/DUPLICATES/{base}.bam.metrics" ],

        [ paired_end and not config["REMOVE_DUP_UMI"], paired_end, paired_end, paired_end, paired_end, paired_end and not config["REMOVE_DUP_UMI"] ])
    singularity:
        GeCKO_image
    params:
        mapper = mapper,
        extra_mapper_options = config["EXTRA_MAPPER_OPTIONS"],
        technology = config["SEQUENCING_TECHNOLOGY"],
        picard_markduplicates_options = config["PICARD_MARKDUPLICATES_OPTIONS"],
        picard_markduplicates_java_options = config["PICARD_MARKDUPLICATES_JAVA_OPTIONS"]
    threads: default_threads
    shell:
        "{scripts_dir}/mapping.sh --paired_end --fastq_R1 \"{input.fastq_paired_R1}\" --fastq_R2 \"{input.fastq_paired_R2}\" --fastq_U \"{input.fastq_unpaired}\" "
        "--ref {input.subref} --mapper {params.mapper} --mapper_options \"{params.extra_mapper_options}\" --technology \"{params.technology}\" "
        "--output_dir {subbams_dir} --sample {wildcards.base} --MD_options \"{params.picard_markduplicates_options}\" "
        "--MD_java_options \"{params.picard_markduplicates_java_options}\" --reports_dir {subbams_reports_dir} --umi {dedupUMI}"


rule Extract_SingleEndReads:
    input:
        bams = bams_dir+"/{base}.bam",
        bed = bed_to_create if create_bed else clean_bed
    output:
        tmp_extract_bams = temp(subbams_dir+"/{base}_extract.bam"),
        tmp_extracted_fastq = temp(subbams_dir+"/{base}_extract.fastq.gz"),
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "samtools view -F 4 -b -L {input.bed} {input.bams} > {output.tmp_extract_bams} ;"
        "picard SamToFastq -I {output.tmp_extract_bams} -F {subbams_dir}/{wildcards.base}_extract.fastq -VALIDATION_STRINGENCY SILENT ;"
        "gzip {subbams_dir}/{wildcards.base}_extract.fastq"


rule Remapping_SingleEndExtractedFastqs:
    input:
        fastq_single = subbams_dir+"/{base}_extract.fastq.gz",
        subref = subref_dir+"/"+ref_name+"_zones.fasta"
    output:
        buildExpectedFiles([ temp(subbams_dir+"/{base}_markedDup.bam"),
        temp(subbams_dir+"/{base}_raw.sam"),
        temp(subbams_dir+"/{base}_sortcoord.bam"),
        subbams_reports_dir+"/DUPLICATES/{base}.bam.metrics" ],

        [ not paired_end and not config["REMOVE_DUP_UMI"], not paired_end, not paired_end, not paired_end and not config["REMOVE_DUP_UMI"] ])
    singularity:
        GeCKO_image
    params:
        mapper = mapper,
        extra_mapper_options = config["EXTRA_MAPPER_OPTIONS"],
        technology = config["SEQUENCING_TECHNOLOGY"],
        picard_markduplicates_options = config["PICARD_MARKDUPLICATES_OPTIONS"],
        picard_markduplicates_java_options = config["PICARD_MARKDUPLICATES_JAVA_OPTIONS"]
    threads: default_threads
    shell:
        "{scripts_dir}/mapping.sh --single_end --fastq \"{input.fastq_single}\" "
        "--ref {input.subref} --mapper {params.mapper} --mapper_options \"{params.extra_mapper_options}\" --technology \"{params.technology}\" "
        "--output_dir {subbams_dir} --sample {wildcards.base} --MD_options \"{params.picard_markduplicates_options}\" "
        "--MD_java_options \"{params.picard_markduplicates_java_options}\" --reports_dir {subbams_reports_dir} --umi {dedupUMI}"


rule Stats_Subbams:
    input:
        subbams_dir+"/{base}_sortcoord.bam" if config["REMOVE_DUP_UMI"] else subbams_dir+"/{base}_markedDup.bam"
    output:
        subbams_stats_reports_dir+"/stats_{base}"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "samtools stats {input} > {output}"


rule Filter_Subbams:
    input:
        subbams_dir+"/{base}_sortcoord.bam" if config["REMOVE_DUP_UMI"] else subbams_dir+"/{base}_markedDup.bam"
    output:
        subbams_dir+"/{base}.bam"
    singularity:
        GeCKO_image
    params:
        samtools_view_filters = config["SAMTOOLS_VIEW_FILTERS2"]
    threads: default_threads
    shell:
        "samtools view -b {params.samtools_view_filters} -o {output} {input}"


rule Summarize_SubbamsReadsCount:
    input:
        expand("{subbams_stats_reports_dir}/stats_{sample}", sample=samples, subbams_stats_reports_dir=subbams_stats_reports_dir),
        expand("{subbams_dir}/{sample}.bam", sample=samples, subbams_dir=subbams_dir)
    output:
        subbams_reports_dir+"/nb_reads_per_sample.tsv"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "{scripts_dir}/summarize_stats.sh --stats_folder {subbams_stats_reports_dir} --bams_folder {subbams_dir} --rmdup FALSE --umi FALSE --output {output};"


rule MultiQC_Subbams:
    input:
        stats_files = expand("{subbams_stats_reports_dir}/stats_{sample}", sample=samples, subbams_stats_reports_dir=subbams_stats_reports_dir)
    output:
        subbams_reports_dir+"/multiQC_ReadMapping_SubBams_Report.html"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "multiqc {input.stats_files} -c {scripts_dir}/config_multiQC_clean_names.yaml -o {subbams_reports_dir} -n multiQC_ReadMapping_SubBams_Report -i ReadMapping_SubBams_Report -f"


rule Index_Subbams:
    input:
        bam = subbams_dir+"/{base}.bam"
    output:
        csi = subbams_dir+"/{base}.bam.csi"
    singularity:
        GeCKO_image
    params:
        samtools_index_options = config["SAMTOOLS_INDEX_OPTIONS"]
    threads: default_threads
    shell:
        "samtools index -c {params.samtools_index_options} {input.bam}"


rule Create_SubbamsList:
    input:
        expand("{subbams_dir}/{sample}.bam", sample=samples, subbams_dir=subbams_dir)
    output:
        mapping_dir+"/subbams_list.txt"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "ls -d {subbams_dir}/*.bam > {output}"


rule Create_RefChrSizeFile:
    input:
        ref
    output:
        ref_fai = ref+".fai",
        chr_size = mapping_dir+"/reference_chr_size.txt"
    singularity:
        GeCKO_image
    threads: default_threads
    shell:
        "samtools faidx {input};"
        "cut -f 1,2 {output.ref_fai} > {output.chr_size}"

rule Write_Summary:
    input:
        buildExpectedFiles(
        [ expand("{bams_dir}/{sample}.bam.csi", sample=samples, bams_dir=bams_dir),
        bams_reports_dir+"/multiQC_ReadMapping_Bams_Report.html",
        bams_reports_dir+"/nb_reads_per_sample.tsv",
        mapping_dir+"/bams_list.txt",
        zones_stats_dir+"/mean_depth_per_zone_per_sample.tsv",
        subref_dir+"/"+ref_name+"_zones.fasta",
        expand("{subbams_dir}/{sample}.bam.csi", sample=samples, subbams_dir=subbams_dir),
        subbams_reports_dir+"/nb_reads_per_sample.tsv",
        subbams_reports_dir+"/multiQC_ReadMapping_SubBams_Report.html",
        mapping_dir+"/subbams_list.txt",
        mapping_dir+"/reference_chr_size.txt" ],
        [ True, True, True, True, count_reads_zones, config["CREATE_SUB_BAMS"], config["CREATE_SUB_BAMS"], config["CREATE_SUB_BAMS"], config["CREATE_SUB_BAMS"], config["CREATE_SUB_BAMS"], config["CREATE_SUB_BAMS"] ])
    output:
        temp(mapping_dir+"/summary.sentinel")
    params:
        latest_info_file = lambda wildcards: find_latest_info_file(mapping_dir),
        new_info_file = workflow_info_file
    threads: default_threads
    shell:
        """
        if [ ! -z "{params.latest_info_file}" ]; then mv {params.latest_info_file} {params.new_info_file} ; fi

        echo -e \"\\t\\t-----------------------------------------------------------------------------\\n\" >> {params.new_info_file}
        echo -e \">>>DATE AND TIME:\" >> {params.new_info_file}
        Date=$(date)
        echo -e \"${{Date}}\\n\" >> {params.new_info_file}
        echo -e \">>>WORKFLOW:\" >> {params.new_info_file}
        echo -e \"https://github.com/GE2POP/GeCKO/tree/main/READ_MAPPING\\n\" >> {params.new_info_file}
        cd {snakefile_dir}
        if git rev-parse --git-dir > /dev/null 2>&1; then echo -e \">>>COMMIT ID:\" >> {params.new_info_file}; git rev-parse HEAD >> {params.new_info_file} ; fi
        cd -
        echo -e \"\\n>>>CONFIG FILE:\" >> {params.new_info_file}
        sed 's/#.*//' {config[configfile_name]} | grep -vP "^\s*$" >> {params.new_info_file}
        if [ {config[clusterprofile_name]} != "NULL" ] ; then
            echo -e \"\\n>>>CLUSTER PROFILE FILE:\" >> {params.new_info_file}
            sed 's/#.*//' {config[clusterprofile_name]} | grep -vP "^\s*$" >> {params.new_info_file}
        fi
        echo -e \"\\n>>>SUMMARY:\" >> {params.new_info_file}
        snakemake --snakefile {snakefile_dir}/ReadMapping.smk --configfile {config[configfile_name]} --summary >> {params.new_info_file}
        echo -e \"\\n\" >> {params.new_info_file}

        touch {output}
        """
