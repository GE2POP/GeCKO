# VARIANT CALLING

This VARIANT_CALLING workflow generates a vcf file from bam files obtained after mapping your reads to a reference genome. This workflow uses GATK to call variants.


### The VARIANT_CALLING workflow's steps
1) An index of the provided reference is created if it does not exist yet
2) A dictionary of the provided reference is created if it does not exist yet
3) The list of chromosomes or contigs in the reference is created for the GenomicsDBImport step 
4) Variant calling by sample is performed with the GATK HaplotypeCaller function
5) A database from variants calling by sample is generated with the GATK GenomicsDBImport function, and a list of the reference's chromosomes or contigs is created
6) Variants calling for all samples (population) is performed with the GATK GenotypeGVCFs function, creating a single vcf file
7) [Optional] (if extracting bams in a sub reference): convert the positions of the variants in the variant file (vcf file) with the positions given in the genomic reference
8) Based on the variant statistics calculated by GATK, histograms are created to estimate the quality of the variant calling before filtration, as well as a boxplot of the observed depth at each genotype (Locus x Sample) and a plot showing the detected variants positioned along the reference genome's contigs


## QUICK START

Needed files:  
- the full GeCKO/ folder, including the runGeCKO.sh launcher  
- your mapped .bam files
- the reference file in fasta format that was used to map your reads
- a VC_CLUSTER_PROFILE folder (in case you work on a cluster) and a config_VariantCalling.yml file

&nbsp;

To easily launch the workflow, use the runGeCKO.sh launcher. For example, to launch the workflow on the BAMS example dataset on a Slurm job-scheduler, run the following command from the EXAMPLE directory:  
```../../runGeCKO.sh --workflow VariantCalling --config-file CONFIG/config_VariantCalling.yml --cluster-profile CONFIG/VC_CLUSTER_PROFILE_SLURM --jobs 20```  

To launch it on your own data, if you cloned the repository in /home/user and placed your config_VariantCalling.yml file and your VC_CLUSTER_PROFILE folder in a CONFIG folder:   
```WORKFLOW_PATH=/home/user/GeCKO```  
```${WORKFLOW_PATH}/runGeCKO.sh --workflow VariantCalling --cluster-profile CONFIG/VC_CLUSTER_PROFILE --jobs 100```  


&nbsp;

![](https://github.com/GE2POP/GeCKO/blob/main/readme\_img/VariantCalling\_4elements.png)


## How to use the VARIANT_CALLING workflow
 
1) [Clone the GitHub repository](#1-clone-the-github-repository)  
2) [Prepare your input data](#2-prepare-your-input-data)  
3) [Prepare the CONFIG files](#3-prepare-the-config-files)  
4) [Launch the analysis](#4-launch-the-analysis)  
5) [Expected outputs](#5-expected-outputs)


### 1/ Clone the GitHub repository

Follow the procedure described [here](https://github.com/GE2POP/GeCKO/tree/main#installation) to have GeCKO ready to process your data.

### 2/ Prepare your input data

The expected input data are .bam files and their associated index files (.bam.bai), along with the reference that was used for the mapping.  

### 3/ Prepare the config files

The VARIANT_CALLING workflow will need information about the dataset and the analysis parameters to perform its different steps.  
These information are provided through two files: a *config.yaml* profile file placed in a specific folder, and a *config_VariantCalling.yml* file. For the latter, if you name it exactly as written above and place it in a folder named 'CONFIG', the bash launching script will detect it automatically. Otherwise, you will have to pass it as an argument with ```--config``` (see [below](#4-launch-the-analysis) for details).

#### *A/ The PROFILE config.yaml file:*
If you intend to execute the workflow on a computer cluster and want it to run tasks in parallel, you must provide the ```--cluster-profile``` parameter with a PROFILE folder. This folder should contain a file named 'config.yaml', giving the needed information to properly submit jobs on the cluster you work on. <ins>Examples of this file, adapted to SGE and SLURM job-schedulers, are provided in the CONFIG folder for the VARIANT_CALLING example dataset</ins>. Depending on your job-scheduler, pick either the VC_CLUSTER_PROFILE_SGE or the VC_CLUSTER_PROFILE_SLURM folder, and adapt the config.yaml to your needs.  
The yaml file is organized into two parts, but you will only need to modify the first one. In this first part, the first section ('default-resources') provides the default values for the cluster's resources (partitions = 'partition' and memory = 'mem_mb') that the workflow should use for all its steps (or rules). If you want to assign a different partition/queue or memory requirement for a specific step, you can specify it in the second section ('set-resources'), and it will overwrite the defaults. Finally, in the last section ('set-threads') you can provide the number of threads/CPUs needed for each step (default = 1).  

You will find [the list of the steps names](#list-of-the-snakefile-rules) along with what they do and the tools they use at the end of this page.  

#### *B/ The config_VariantCalling.yml file:*  
This file is used to pass all the information and tools parameters that will be used by the VARIANT_CALLING workflow. The workflow expects it to contain a specific list of variables and their assigned values, organized in YAML format. Expected variables are:  

**GENERAL VARIABLES**  
- *VARIANT_CALLING_SUBFOLDER:*&nbsp;&nbsp;&nbsp;If you want to separate results from different variants calling parameters (different reference, mapping options...), provide a name for an extra folder to create in the VARIANT_CALLING output folder. Otherwise leave blank ("").  

**INPUT FILES**  
- *BAMS_LIST:*&nbsp;&nbsp;&nbsp;The path to the file containing the list of paths to the mapped bam files and index files in .bam.bai format. If the bams to be used for the VARIANT_CALLING have been mapped to the full genomic reference, use the file: bams_list.txt. If the bams to be used for the VARIANT_CALLING have been extracted on the basis of a sub reference (subbams), use the file: subbams_list.txt. These lists are generated by the READ_MAPPING workflow and are stored in: WORKFLOWS_OUTPUTS/READ_MAPPING
- *REFERENCE:*&nbsp;&nbsp;&nbsp;The path to the reference file in fasta format (must end with .fa, .fas or .fasta) used for the mapping. 
- *GENOMIC_REFERENCE_CHR_SIZE:*&nbsp;&nbsp;&nbsp;If your input bams result from an extraction of the reads mapping to specific genomic zones (i.e. CREATE_SUB_BAMS was set to TRUE during the mapping step) and you want the variants positions in this workflow's output vcf file to be given in the whole genomic reference, then please provide here the path to the reference_chr_size.txt file containing your genomic reference chromosomes sizes. This file is automatically created by the READ_MAPPING workflow when CREATE_SUB_BAMS is set to TRUE, and stored in WORKFLOWS_OUTPUTS/READ_MAPPING. Otherwise leave blank ("").  

**VARIANT CALLING PARAMETERS**  
For each of the three GATK steps, two options fields are available: options related to the use of java (JAVA_OPTIONS) and step-specific options (EXTRA_OPTIONS) , if not leave blank: ""

- *GATK_HAPLOTYPE_CALLER_JAVA_OPTIONS:*&nbsp;&nbsp;&nbsp;Java options for the GATK HaplotypeCaller function (eg: "-Xmx4g"). Be careful to provide them between quotes.
- *GATK_HAPLOTYPE_CALLER_EXTRA_OPTIONS:*&nbsp;&nbsp;&nbsp;Any list of options you would like to pass to the 'GATK Haplotypecaller' command. Be careful to provide them between quotes.
- *GATK_GENOMICS_DB_IMPORT_JAVA_OPTIONS:*&nbsp;&nbsp;&nbsp;Java options for the GATK GenomicsDBImport function (eg: "-Xmx30g"). Be careful to provide them between quotes.
- *GATK_GENOMICS_DB_IMPORT_EXTRA_OPTIONS:*&nbsp;&nbsp;&nbsp;Any list of options you would like to pass to the 'GATK GenomicsDBImport' command (eg: "--merge-contigs-into-num-partitions 20 --batch-size 50 --reader-threads 20"). Be careful to provide them between quotes.
- *GATK_GENOTYPE_GVCFS_JAVA_OPTIONS:*&nbsp;&nbsp;&nbsp;Java options for the GATK GenotypeGVCFs function (eg: "-Xmx30g"). Be careful to provide them between quotes.
- *GATK_GENOTYPE_GVCFS_EXTRA_OPTIONS:*&nbsp;&nbsp;&nbsp;Any list of options you would like to pass to the 'GATK GenotypeGVCFs' command (eg: "--include-non-variant-sites --heterozygosity 0.001). Be careful to provide them between quotes.

&nbsp;

<ins>An example of config_VariantCalling.yml file can be found in the EXAMPLE/CONFIG folder</ins>.  

&nbsp;


### 4/ Launch the analysis

**Environment**  
You can run this workflow on a computer or on a computer cluster. You will need Snakemake and Singularity to be available.    

**Launching**  
To launch the VARIANT_CALLING workflow, assuming you placed your config_VariantCalling.yml and VC_CLUSTER_PROFILE folder in a CONFIG folder, use the launching script runGeCKO.sh with the option --workflow VariantCalling:  
```WORKFLOW_PATH=/home/user/GeCKO```  
```${WORKFLOW_PATH}/runGeCKO.sh --workflow VariantCalling --cluster-profile CONFIG/VC_CLUSTER_PROFILE --jobs 100```   

⚠ All the input data should be located somewhere within your home directory (as returned by ```echo $HOME```).  

For more help on how to use the launcher, see GeCKO's general [README](https://github.com/GE2POP/GeCKO/tree/main#quick-start), or run:  
```${WORKFLOW_PATH}/runGeCKO.sh --help```  


### 5/ Expected outputs  

This workflow will create a "VARIANT_CALLING" directory in the "WORKFLOWS_OUTPUTS" directory. This directory is structured as follows and contains:  

<img src="https://github.com/GE2POP/GeCKO/blob/main/readme_img/OutputsTree_VariantCalling.png" width="600"/>



<ins>Description of the main files:</ins> 

- *workflow_info.txt*:&nbsp;&nbsp;&nbsp;File containing the date and time of the workflow launch, the link to the Github repository, the corresponding commit ID, and a copy of the config files provided by the user

**HAPLOTYPE_CALLER directory**  
- Two files by sample, the vcf.gz file (sample.g.vcf.gz) and the associated index file (sample.g.vcf.gz.tbi). A list of the vcf files contained in this folder will also be here (vcf.list.txt).  

**GENOMICS_DB_IMPORT directory** 
- Several directories containing the GATK data base and associated files (.json, .vcf and . tdb)  

**GENOTYPE_GVCFS directory**
- If the VARIANT_CALLING was performed on the full genomic reference: this folder contains final variant_calling.vcf.gz file and its associated index (variant_calling.vcf.gz.tbi)  
- If the VARIANT_CALLING was performed on the basis of a sub reference (subbams) and the positions of the variants (vcf file) were converted to the genomic reference, this folder contains final variant_calling_converted.vcf.gz file and its associated index (variant_calling_converted.vcf.gz.csi)
- **REPORTS directory** contains:  
    - *variants_stats_VC.tsv*:&nbsp;&nbsp;&nbsp;&nbsp; file that summarizes the statistics per locus present in the vcf file before filtering
    - *variants_stats_histograms_VC.pdf*:&nbsp;&nbsp;&nbsp;&nbsp; file with histograms based on locus statistics before filtering
    - *genotypes_DP_boxplot_VC.pdf*:&nbsp;&nbsp;&nbsp;&nbsp; file with a boxplot of the observed depth at each genotype, along with the percentage of missing values in the vcf file
    - *variants_along_genome_VC.pdf*:&nbsp;&nbsp;&nbsp;&nbsp; file with a plot showing the detected variants positioned along the reference genome's contigs

## Tools
This workflow uses the following tools: 
- [gatk v4.6.1.0](https://github.com/broadinstitute/gatk/)
- [samtools v1.21](https://github.com/samtools/samtools/)
- [bcftools v1.21](https://samtools.github.io/bcftools/bcftools.html)
- [seaborn v0.13.2](https://seaborn.pydata.org/)
- [matplotlib v3.9.1](https://matplotlib.org/)
- [pandas v2.2.3](https://pandas.pydata.org/)
- [numpy v2.0.2](https://numpy.org/)

These tools are pre-installed in the Singularity image automatically downloaded by the launcher and used by Snakemake to run each rule.

##  List of the snakefile rules
Name, description and tools used for each of the snakemake workflow rules:

| **Rule name**                     | **Description**                                                                 | **Tools**                     |
|:---------------------------------:|:-------------------------------------------------------------------------------:|:-----------------------------:|
| Index_Reference                   | Creating the reference index if needed                                          | samtools faidx                |
| Dictionary_Reference              | Creating the reference dictionnary for gatk if needed                           | gatk CreateSequenceDictionary |
| ListIntervalsReference_Dictionary | Listing chromosomes/contigs in the dictionnary for gatk GenomicsDBImport        |                               |
| HaplotypeCaller                   | Calling variants by sample                                                      | gatk HaplotypeCaller          |
| List_Haplotype                    | Listing sample files (g.vcf.gz) from HaplotypeCaller for gatk GenomicsDBImport  |                               |
| GenomicsDBImport                  | Creating data base from variants calling by sample and the intervals list       | gatk GenomicsDBImport         |
| GenotypeGVCFs                     | Calling variants for all samples (population) from GenomicsDBImport to vcf file | gatk GenotypeGVCFs            |
| ConvertPositions                  | Convert the positions of the variants (in vcf file) on the genomic reference    |                               |
| Summarize_GVCFVariables           | Recovery and summarize GATK locus statistics                                    | bcftools query                |
| Plot_GVCFVariablesHistograms      | Creating histograms based on GATK locus statistics                              | seaborn, pyplot               |
| Plot_GVCFDPBoxplot                | Creating a boxplot of the depth at each genotype                                | pyplot                        |
| Plot_GVCFVariantsAlongGenome      | Creating a plot of the detected variants along the genome                       | pyplot                        |


![Image non trouvée : https://github.com/GE2POP/GeCKO/blob/main/readme_img/VariantCalling_Workflow.jpg?raw=true](https://github.com/GE2POP/GeCKO/blob/main/readme_img/VariantCalling_Workflow.jpg?raw=true)
