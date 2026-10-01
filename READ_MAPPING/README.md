# READ MAPPING

This READ_MAPPING workflow generates bams files from demultiplexed cleaned sequences.

It can be used to process:  
- Single-end sequences (SE), sequenced from only one end of each DNA fragment.  
- Paired-end sequences (PE), sequenced from both ends of each DNA fragment.  

### The READ_MAPPING workflow's steps
1) An index of the provided reference is created if it does not exist yet.
2) Reads are mapped to the reference, the resulting bams are sorted, duplicates are removed if needed (using either Picard MarkDuplicates for standard data or umi_tools dedup if UMIs were incorporated during library construction), the reads are filtered as specified by the user, and the final bams are indexed.
3) Total and mapped reads are counted at each step, and a MultiQC report is created, showing the reads numbers and quality after the mapping step.
4) *[Optional]* For each genomic region provided in a bed file (or automatically determined by the workflow), reads are counted in each sample.
5) *[Optional]* Targeted remapping: a sub-reference corresponding to the bed regions is produced. The reads that mapped to these regions are extracted and re-mapped to the sub-reference. The resulting sub-bams are sorted, filtered as specified by the user, and the final sub-bams are indexed.
6) *[Optional]* Total and mapped reads are counted before and after the second filtering step, and a MultiQC report is created, showing the reads numbers and quality after remapping the reads to the sub-reference.




## QUICK START

Needed files:  
- the full GeCKO/ folder, including the runGeCKO.sh launcher  
- your demultiplexed and trimmed fastq.gz files
- a reference file in fasta format to map your reads to
- (optional) a bed file listing genomic regions of interest 
- a RM_CLUSTER_PROFILE folder (in case you work on a cluster) and a config_ReadMapping.yml file  


&nbsp;

To easily launch the workflow, use our runGeCKO.sh launcher. For example, to launch the workflow on our example PAIRED_END DEMULT_TRIM dataset on a Slurm job-scheduler, run the following command from the EXAMPLE/PAIRED_END directory:  
```../../../runGeCKO.sh --workflow ReadMapping --config-file CONFIG/config_ReadMapping.yml --cluster-profile CONFIG/RM_CLUSTER_PROFILE_SLURM --jobs 20```  

To launch it on your own data, if you cloned the repository in /home/user and placed your config_ReadMapping.yml file and your RM_CLUSTER_PROFILE folder in a CONFIG folder:  
```WORKFLOW_PATH=/home/user/GeCKO```  
```${WORKFLOW_PATH}/runGeCKO.sh --workflow ReadMapping --cluster-profile CONFIG/RM_CLUSTER_PROFILE --jobs 100``` 


&nbsp;

![](https://github.com/GE2POP/GeCKO/blob/main/readme_img/ReadMapping\_4elements.png)

&nbsp;


## How to use the READ_MAPPING workflow
 
1) [Clone the GitHub repository](#1-clone-the-github-repository)  
2) [Prepare your input data](#2-prepare-your-input-data) 
3) [Prepare the CONFIG files](#3-prepare-the-config-files)  
4) [Launch the analysis](#4-launch-the-analysis)  
5) [Expected outputs](#5-expected-outputs)

### 1/ Clone the GitHub repository

Follow the procedure described [here](https://github.com/GE2POP/GeCKO/tree/main#installation) to have GeCKO ready to process your data.

### 2/ Prepare your input data

The input data must be sequences from an Illumina sequencer (Miseq/Hiseq/Novaseq/...). 

Input sequences can be:  
- single-end sequences (SE): you must provide fastq files named in the format \*name\*.fastq.gz  
- paired-end sequences (PE): you must provide pairs of fastq files named in the format \*name\*.R1.fastq.gz and \*name\*.R2.fastq.gz

If you processed your raw data using GeCKO's DataCleaning workflow, the resulting fastq files located in the WORKFLOWS_OUTPUTS/DATA_CLEANING/DEMULT_TRIM directory would serve as the input files for this workflow.

### 3/ Prepare the config files

The READ_MAPPING workflow will need information about the dataset and the analysis parameters to perform its different steps.  
These information are provided through two files: a *config.yaml* profile file placed in a specific folder, and a *config_ReadMapping.yml* file. For the latter, if you name it exactly as written above and place it in a folder named 'CONFIG', the bash launching script will detect it automatically. Otherwise, you will have to pass it as an argument with ```--config``` (see [below](#4-launch-the-analysis) for details).

#### *A/ The PROFILE config.yaml file:*
If you intend to execute the workflow on a computer cluster and want it to run tasks in parallel, you must provide the ```--cluster-profile``` parameter with a PROFILE folder. This folder should contain a file named 'config.yaml', giving the needed information to properly submit jobs on the cluster you work on. <ins>Examples of this file, adapted to SGE and SLURM job-schedulers, are provided in the CONFIG folder for each READ_MAPPING example dataset</ins>. Depending on your job-scheduler, pick either the RM_CLUSTER_PROFILE_SGE or the RM_CLUSTER_PROFILE_SLURM folder, and adapt the config.yaml to your needs.  
The yaml file is organized into two parts, but you will only need to modify the first one. In this first part, the first section ('default-resources') provides the default values for the cluster's resources (partitions = 'partition' and memory = 'mem_mb') that the workflow should use for all its steps (or rules). If you want to assign a different partition/queue or memory requirement for a specific step, you can specify it in the second section ('set-resources'), and it will overwrite the defaults. Finally, in the last section ('set-threads') you can provide the number of threads/CPUs needed for each step (default = 1).   

You will find [the list of the steps names](#list-of-the-snakefile-rules) along with what they do and the tools they use at the end of this page.  

#### *B/ The config_ReadMapping.yml file:*  
This file is used to pass all the information and tools parameters that will be used by the READ_MAPPING workflow. The workflow expects it to contain a specific list of variables and their assigned values, organized in YAML format. Expected variables are:  

**GENERAL VARIABLES**  
- *PAIRED_END:*&nbsp;&nbsp;&nbsp;Whether your data is paired-end or single-end. [TRUE or FALSE]  
- *CREATE_SUB_BAMS:*&nbsp;&nbsp;&nbsp;Whether to extract reads from regions of interest (listed in bed file) and to create the corresponding sub-bams (we call this process "targeted remapping"). <ins>If your reference genome includes chromosomes longer than 512 Mb and you intend to call variants on your data, please note that SNP callers such as GATK cannot process chromosomes of such lengths effectively. In such cases, performing a targeted remapping is advised, as it will produce reads mapped to shorter contigs.</ins> Cannot be set to TRUE if the BED variables are left blank. If set to TRUE, please read [this section](#how-to-fill-in-the-configuration-file-for-extracting-and-remapping-reads-from-specific-zones-create_sub_bams-set-to-true) to understand how to properly set up your config file. [TRUE or FALSE]  
- *MAPPING_SUBFOLDER:*&nbsp;&nbsp;&nbsp;If you want to separate results from different mapping parameters (different reference, mapping options...), provide a name for an extra folder to create in the READ_MAPPING output folder. Otherwise leave blank ("").  

**INPUT FILES**  
- *TRIM_DIRS:*&nbsp;&nbsp;&nbsp;The path(s) to the directory or directories containing the trimmed fastq files to be mapped. If left blank, the workflow will assume the fastq files are in WORKFLOWS_OUTPUTS/DATA_CLEANING/DEMULT_TRIM, which is the path to the DATA_CLEANING workflow output files. To provide several directories, separate them with spaces, e.g.: "/home/user/trim_dir1 /home/user/trim_dir2". Be careful to provide them between quotes.   
- *REFERENCE:*&nbsp;&nbsp;&nbsp;The path to the reference file in fasta format (must end with .fa, .fas or .fasta).  

*If you set CREATE_SUB_BAMS to TRUE, you either have to provide a bed file:*
- *BED:*&nbsp;&nbsp;&nbsp;The path to the bed file listing regions of interest to count reads in, in format "chr start end", separated with tabulations. Optional: can be left blank ("").  

*Or to provide ALL of the three following parameters to automatically create a bed file containing the genomic regions with enough coverage in your dataset:*
- *BED_MIN_MEAN_COV:*&nbsp;&nbsp;&nbsp;The minimum mean depth per sample (number of reads per base) to keep a genomic region. Optional: can be left blank ("").
- *BED_MIN_DIST:*&nbsp;&nbsp;&nbsp;The minimum distance allowed between two regions. If several regions are separated by a smaller distance than this, they will be merged into a single one. Optional: can be left blank ("").
- *BED_MIN_LENGTH:*&nbsp;&nbsp;&nbsp;The minimum length to keep a region after merging. Optional: can be left blank ("").

**MAPPING PARAMETERS**  
- *MAPPER:*&nbsp;&nbsp;&nbsp;The name of the mapper you want to use. Currently implemented options are 'bwa-mem2_mem', 'bwa_mem', 'bowtie2' and 'minimap2'.   
- *SEQUENCING_TECHNOLOGY:*&nbsp;&nbsp;&nbsp;The name of the sequencing technology (eg: "ILLUMINA"), which will appear in the reads names after mapping: 'PL:{SEQUENCING_TECHNOLOGY}')  
- *EXTRA_MAPPER_OPTIONS:*&nbsp;&nbsp;&nbsp;Any list of options you would like to pass to the mapper command. Be careful to provide them between quotes. 
- *PICARD_MARKDUPLICATES_OPTIONS:*&nbsp;&nbsp;&nbsp;Any list of options you would like to pass to the 'picard MarkDuplicates' command. Be careful to provide them between quotes.  
- *SAMTOOLS_INDEX_OPTIONS:*&nbsp;&nbsp;&nbsp;Any list of options you would like to pass to the 'samtools index' command. Be careful to provide them between quotes. The "-c" option is already included.

**BAM FILTERING**
- *REMOVE_DUP_MARKDUPLICATES:*&nbsp;&nbsp;&nbsp;Whether or not to remove duplicates with 'picard MarkDuplicates' after the mapping step. If set to TRUE, set REMOVE_DUP_UMI to FALSE. If both REMOVE_DUP_MARKDUPLICATES and REMOVE_DUP_UMI are set to FALSE, duplicates will be marked with 'picard MarkDuplicates'. Setting both REMOVE_DUP_MARKDUPLICATES and REMOVE_DUP_UMI to TRUE will raise an error. [TRUE or FALSE]  
- *REMOVE_DUP_UMI:*&nbsp;&nbsp;&nbsp;Whether or not to remove duplicates with 'umi_tools dedup' after the mapping step. This option requires prior extraction of UMI sequences from the reads using 'umi_tools extract' (this can be done with the DataCleaning workflow by setting UMI: TRUE). If set to TRUE, set REMOVE_DUP_MARKDUPLICATES to FALSE. If both REMOVE_DUP_UMI and REMOVE_DUP_MARKDUPLICATES are set to FALSE, duplicates will be marked with 'picard MarkDuplicates'. Setting both REMOVE_DUP_MARKDUPLICATES and REMOVE_DUP_UMI to TRUE will raise an error. [TRUE or FALSE]  
- *UMITOOLS_DEDUP_OPTIONS:*&nbsp;&nbsp;&nbsp;Any list of options or parameters you would like to pass to the 'umi_tools dedup' command. Be careful to provide them between quotes. See the [umi_tools dedup documentation](https://umi-tools.readthedocs.io/en/latest/reference/dedup.html) to read more about its options. 
- *SAMTOOLS_VIEW_FILTERS1:*&nbsp;&nbsp;&nbsp;Any list of filters you would like to pass to the 'samtools view' command after the mapping step. Eg for CREATE_SUB_BAMS set to TRUE: "-F 256 -F 2048 -f 2" to discard unproperly paired, non primary and supplementary reads before the extraction step. Eg for CREATE_SUB_BAMS set to FALSE: "-q 30" to discard alignments with a mapping quality (MAPQ score) lower than 30.   
- *SAMTOOLS_VIEW_FILTERS2:*&nbsp;&nbsp;&nbsp;Any list of filters you would like to pass to the 'samtools view' command after the remapping step. Eg: "-q 30" to discard alignments with a mapping quality (MAPQ score) lower than 30. If CREATE_SUB_BAMS is set to FALSE, leave blank (the command will not be called anyway).

See the samtools view documentation [here](https://www.htslib.org/doc/samtools-view.html) to read more about the -F, -f, -q options.

&nbsp;

<ins>Examples of config_ReadMapping.yml files can be found in the EXAMPLE/.../CONFIG folders</ins>.  

&nbsp;

### *How to fill in the configuration file for extracting and remapping reads from specific zones (CREATE_SUB_BAMS set to TRUE)*
**⚠ Warning**  
Performing targeted remapping can affect the flags of the mapped reads alignments, which in some cases may change compared to the results obtained after the first mapping. We have taken measures to avoid the most problematic issues: particularly, two reads of a pair flagged as properly paired at the end of mapping on the complete reference will not become improperly paired after targeted remapping.  
However, it remains possible that paired reads (either properly or improperly paired) may become single. The following paragraphs provide advice on minimizing these occurrences.

- Bed file  
<ul>
In case you <ins>provide your own bed file</ins>, you will probably want to list zones targeted by your baits. To do so, you can use the ncbi 'blast' tool to blast your baits onto the reference genome and identify potential capture regions:

```blastn -task blastn -query baits.fasta -db reference.fasta -out blast_baits_on_reference.txt -outfmt '6 qseqid sseqid qstart qend qlen sstart send slen length pident evalue nident'```  

Based on metrics such as e-value or nident, filter the blast output to select genomic zones that exhibit sufficient similarity and are likely to hybridize with your baits during the capture step. The resultant bed file should contain three columns (chromosome, start, end), separated with tabs. When converting blast coordinates to bed format, ensure that for all lines the start position is less than the end position, which will require reversing the coordinates when the alignment is to the reverse complement of the reference (indicated as the negative strand in blast output). Additionally, consider whether to include margins around the targeted regions (e.g., start-300, stop+300) to ensure coverage of sequenced fragments that might extend beyond the length of the baits.  

We also strongly recommend merging proximal regions. This will prevent the potential issue of initially (properly or improperly) paired reads being remapped into distinct zones, which would result in them both being considered single during the remapping step.

Please note that any overlapping regions present in your BED file will be automatically merged into a single contiguous region. The resulting BED file (user_clean.bed), featuring the merged zones, will be available in the WORKFLOWS_OUTPUTS/READ_MAPPING/*/EXTRACTED_BAMS/REFERENCE_zones/ output folder.
</ul>
&nbsp
<ul>
Should you prefer to have the workflow <ins>automatically identify regions of interest</ins>, it will compute the read depth across the genome for all samples, and only retain zones that exceed the BED_MIN_MEAN_COV mean depth threshold. Subsequently, regions within a distance less than BED_MIN_DIST will be merged together, and any resulting regions shorter than BED_MIN_LENGTH will be excluded.  

We advise setting the BED_MIN_DIST parameter to a value exceeding the difference between the fragment size and twice the read sequencing length. For instance, with DNA fragments averaging 500bp and both R1 and R2 reads being 150bp, a BED_MIN_DIST value greater than 200 is recommended.
</ul>

- Filtering  
Bam filtering options are available after both the initial mapping (SAMTOOLS_VIEW_FILTERS1) and remapping (SAMTOOLS_VIEW_FILTERS2) steps. To ensure the integrity of read extraction and remapping, it is best to remove improperly paired reads, as well as non-primary and supplementary alignments, after the first mapping. This precaution helps prevent the misclassification of improperly paired reads as single reads if only one read of a pair is preserved or if the two reads mapped in different zones. Furthermore, in the absence of the primary read (in case it mapped out of the extracted zones), secondary or supplementary alignments could be incorrectly designated as primary during the remapping step. Such misclassifications can lead to the erroneous interpretation of mapping quality, resulting in inaccuracies in downstream analysis and the potential overestimation of certain reads' reliability. To filter out improperly paired, non primary and supplementary reads, set SAMTOOLS_VIEW_FILTERS1 to "-F 256 -F2048 -f2" (see [here](https://broadinstitute.github.io/picard/explain-flags.html) to understand sam flags and [here](https://www.htslib.org/doc/samtools-view.html) for more information on samtools view's -F and -f options).


### 4/ Launch the analysis

**Environment**  
You can run this workflow on a computer or on a computer cluster. You will need Snakemake and Singularity to be available.    

**Launching**  
To launch the READ_MAPPING workflow, assuming you placed your config_ReadMapping.yml and RM_CLUSTER_PROFILE folder in a CONFIG folder, use the launching script runGeCKO.sh with the option --workflow ReadMapping:  
```WORKFLOW_PATH=/home/user/GeCKO```  
```${WORKFLOW_PATH}/runGeCKO.sh --workflow ReadMapping --cluster-profile CONFIG/RM_CLUSTER_PROFILE --jobs 100``` 

⚠ All the input data should be located somewhere within your home directory (as returned by ```echo $HOME```).  

For more help on how to use the launcher, see GeCKO's general [README](https://github.com/GE2POP/GeCKO/tree/main#quick-start), or run:  
```${WORKFLOW_PATH}/runGeCKO.sh --help```  



### 5/ Expected outputs  

This workflow will create a "READ_MAPPING" directory in the "WORKFLOWS_OUTPUTS" directory. This directory is structured as follows and contains:  

<img src="https://github.com/GE2POP/GeCKO/blob/main/readme_img/OutputsTree_ReadMapping.png" width="600"/>



<ins>Description of the main files:</ins>  

- *bams_list.txt*:&nbsp;&nbsp;&nbsp;File containing the list of paths to bams files
- *reference_chr_size.txt*:&nbsp;&nbsp;&nbsp;File containing the name and size of each chromosome in the genomic reference (just if "CREATE_SUB_BAMS: TRUE")
- *subbams_list.txt*:&nbsp;&nbsp;&nbsp;File containing the list of paths to subbams files (just if "CREATE_SUB_BAMS: TRUE")
- *workflow_info.txt*:&nbsp;&nbsp;&nbsp;File containing the date and time of the workflow launch, the link to the Github repository, the corresponding commit ID, and a copy of the config files provided by the user

**BAMS directory**  
- *bams files*:&nbsp;&nbsp;&nbsp;One file per sample, reads mapped to the provided reference along with the associated index file (.csi).  

**BAMS/REPORTS directory**  
- *nb_reads_per_sample.tsv*:&nbsp;&nbsp;&nbsp;Number of reads per sample after mapping  
- *DUPLICATES directory*:&nbsp;&nbsp;&nbsp;MarkDuplicates reports (one per sample)  
- *STATS directory*:&nbsp;&nbsp;&nbsp;Samtools stats reports (one per sample)  
- *multiQC_ReadMapping_Bams_Report.html (and the associated directory)*:&nbsp;&nbsp;&nbsp;Graphic report based on stats reports to visualize the number and percentages of mapped reads  

**EXTRACTED_BAMS/BAMS_ZONES directory** (if a bed file was provided and CREATE_SUB_BAMS was set to TRUE)  
- *bams files*:&nbsp;&nbsp;&nbsp;One file per sample, reads that mapped to the zones provided in the bed file, with coordinates given in the corresponding sub-reference  

**EXTRACTED_BAMS/BAMS_ZONES/REPORTS directory** (if a bed file was provided and CREATE_SUB_BAMS was set to TRUE)  
- *nb_reads_per_sample.tsv*:&nbsp;&nbsp;&nbsp;Number of reads per sample after mapping and extraction  
- *DUPLICATES directory*:&nbsp;&nbsp;&nbsp;MarkDuplicates reports (one per sample)  
- *STATS directory*:&nbsp;&nbsp;&nbsp;Samtools stats reports (one per sample)  
- *multiQC_ReadMapping_SubBams_Report.html (and the associated directory)*:&nbsp;&nbsp;&nbsp;Graphic report based on stats reports to visualize the number and percentages of mapped reads in sub-bams  

**EXTRACTED_BAMS/REFERENCE_ZONES directory** (if a bed file was provided and CREATE_SUB_BAMS was set to TRUE)  
- *zones.bed*:&nbsp;&nbsp;&nbsp;Bed file containing the positions (start - end) of the genomic regions with enough coverage.
- *Reference_zones.fasta*:&nbsp;&nbsp;&nbsp;The sub-reference, corresponding to the extraction of the zones provided in the bed file.  

**ZONES_STATS directory** (if a bed file was provided) 
- *mean_depth_per_zone_per_sample.tsv*:&nbsp;&nbsp;&nbsp;For each zone and each sample, the mean depth per zone (number of reads per base) 




## Tools
This workflow uses the following tools: 
- [bwa-mem2 v2.2.1](https://github.com/bwa-mem2/bwa-mem2)
- [bwa v0.7.18](https://github.com/lh3/bwa)
- [bowtie2 v2.5.4](https://github.com/BenLangmead/bowtie2)
- [minimap2 v2.28](https://github.com/lh3/minimap2)
- [samtools v1.21](http://www.htslib.org/)
- [picard v3.3.0](https://broadinstitute.github.io/picard/)
- [UMI_tools v1.1.5](https://umi-tools.readthedocs.io/en/latest/index.html)
- [multiqc v1.25.1](https://github.com/ewels/MultiQC/releases)
- [bedtools v2.31.1](https://github.com/arq5x/bedtools2)

These tools are pre-installed in the Singularity image automatically downloaded by the launcher and used by Snakemake to run each rule.

##  List of the snakefile rules
Name, description and tools used for each of the snakemake workflow rules:

| **Rule name**               | **Description**                                                                                                                     | **Tools**                                                                                                                              |
|:---------------------------:|:-----------------------------------------------------------------------------------------------------------------------------------:|:--------------------------------------------------------------------------------------------------------------------------------------:|
| Index_Reference             | Creating the reference index if needed                                                                                              | bwa index // bwa-mem2 index // bowtie2-build // minimap2 -d                                                                            |
| Mapping_PairedEndFastqs     | Mapping the input fastq files onto the reference (paired end reads)                                                                 | bwa mem // bwa-mem2 mem // bowtie2 // minimap2; samtools sort; picard MarkDuplicates                                                          |
| Mapping_SingleEndFastqs     | Mapping the input fastq files onto the reference (single end reads)                                                                 | bwa mem // bwa-mem2 mem // bowtie2 // minimap2; samtools sort; picard MarkDuplicates                                                          |
| Stats_Bams                  | Computing mapping stats                                                                                                             | samtools stats                                                                                                                         |
| MarkDuplicates_Bams         | Marking and removing duplicates if needed                                                                                      | picard MarkDuplicates                                                                                                  |
| DedupUMI_Bams         | Removing true duplicates using UMI information                                                                                       | umi_tools dedup                                                                                                  |
| Filter_Bams                  | Filtering bams after the first mapping step                                                                                                                 | samtools view                                                                                                                         |
| Index_Bams                  | Creating bams index                                                                                                                 | samtools index                                                                                                                         |
| Summarize_BamsReadsCount    | Summarizing reads count in bams from samtools stats output                                                                          |                                                                                                                                        |
| MultiQC_Bams                | Running MultiQC on samtools stats output                                                                                             | MultiQC                                                                                                                                |
| Create_BamsList             | Writing list of bams files                                                                                                          |                                                                                                                                        |
| Clean_BedFile             | Merging overlapping regions in the provided bed file                                                                                                          |                                                                                                                                        |
| Create_BedFile              | Automatically creating a bed file containing the covered zones identified after the first mapping                                                                                 | samtools merge; bedtools genomecov                                                                                                     |
| CountReadsZones_Bams        | Counting reads in each zone of the bed file for each sample                                                                | samtools bedcov                                                                                                                        |
| Create_SubReference         | Generating the reduced reference corresponding to the genomic zones provided in the bed file                                        | samtools faidx                                                                                                                         |
| Extract_PairedEndReads               | Extracting reads that mapped to the zones provided in the bed file (paired end reads)                                           | samtools view, sort, fixmate, merge; picard SamToFastq                                                                                                                               |
| Remapping_PairedEndExtractedFastqs               | Mapping the extracted reads to the subreference (paired end reads)                                           | bwa mem // bwa-mem2 mem // bowtie2 // minimap2; samtools sort; picard MarkDuplicates                                                                                                                               |
| Extract_SingleEndReads               | Extracting reads that mapped to the zones provided in the bed file (single end reads)                                           | samtools view; picard SamToFastq                                                                                                                               |
| Remapping_SingleEndExtractedFastqs               | Mapping the extracted reads to the subreference (single end reads)                                           | bwa mem // bwa-mem2 mem // bowtie2 // minimap2; samtools sort; picard MarkDuplicates                                                                                                                               |
| Stats_Subbams               | Computing mapping stats for subbams                                                                                                 | samtools stats                                                                                                                         |
| Filter_Subbams                  | Filtering subbams after the remapping step                                                                                                                 | samtools view                                                                                                                         |
| Index_Subbams               | Creating subbams index                                                                                                              | samtools index                                                                                                                         |
| Summarize_SubbamsReadsCount | Summarizing reads count in subbams from samtools stats output                                                                       |                                                                                                                                        |
| MultiQC_Subbams             | Running MultiQC on samtools stats output                                                                                             | MultiQC                                                                                                                                |
| Create_SubbamsList          | Writing list of subbams files                                                                                                       |                                                                                                                                        |
| Create_RefChrSizeFile       | Creating file with the name and size of each chromosome in the genomic reference                                                    | samtools faidx                                                                                                                         |



<!-- ![](https://github.com/GE2POP/GeCKO/blob/main/readme_img/ReadMapping_Workflow.jpg?raw=true) -->
