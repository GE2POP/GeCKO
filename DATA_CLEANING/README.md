# DATA CLEANING

This DATA_CLEANING workflow generates demultiplexed cleaned sequences from raw sequenced data.

It can be used to process:  
- Single-end sequences (SE), sequenced from only one end of each DNA fragment.  
- Paired-end sequences (PE), sequenced from both ends of each DNA fragment.  

Besides, input sequences can be :
- Multiplexed (sequences of several samples packed in only one (SE) or a pair of (PE) fastq.gz files)
- Demultiplexed (sequences of each sample packed in separate fastq.gz files, one per sample if SE or a pair if PE)



### The DATA_CLEANING workflow's steps
Steps 1, 2, 3 are done for mulitplexed data and skipped otherwise. 
1) Quality analysis of raw sequences/reads from sequencing (FASTQC)  
2) Counting the number of reads in one (SE) or two (PE) fastq.gz input files  
3) Demultiplex one (SE) or two (PE) fastq.gz files into individual fastq files based on the barcode or tag specific to each sample (CUTADAPT)  
4) Counting the number of reads in one (SE) or two (PE) fastq.gz files per sample  
5) Trimming one (SE) or two (PE) fastq.gz files per sample to remove adapters sequences, low quality sequences et short sequences (CUTADAPT)  
6) Counting the number of reads in one (SE) or two (PE) fastq.gz files per sample  
7) Quality analysis of each sample's reads, after demultiplexing and trimming (FASTQC)  
8) Creation of two reports (MultiQC) allowing to visualise the impact of the trimming step on the quality of the sequences (for each individual sample), and the impact of the whole workflow (for all samples merged together).  

![](https://github.com/BioInfo-GE2POP-BLE/CAPTURE_PIPELINES_SNAKEMAKE/blob/main/readme_img/DataCleaning_Workflow.jpg?raw=true)


&nbsp;


## QUICK START

To easily launch the workflow, use our runSnakemakeWorkflow.sh launcher:  
```./runSnakemakeWorkflow.sh --workflow DataCleaning --workflow-path PATH/TO/CAPTURE_SNAKEMAKE_WORKFLOWS```  

Needed files:  
- the full CAPTURE_SNAKEMAKE_WORKFLOWS/ folder  
- the runSnakemakeWorkflow.sh launcher  
- your raw fastq.gz file(s)  
- the cluster_config_DataCleaning.yml (in case you work on a cluster) and config_DataCleaning.yml files in a CONFIG folder  
- a barcode file in case of multiplexed data and an adapter file  

&nbsp;

For example, if you need to launch the workflow on our MULTIPLEXED_PAIRED_END dataset on a Slurm job-scheduler, run the following command from the EXAMPLE/MULTIPLEXED_PAIRED_END directory:  
```./runSnakemakeWorkflow.sh --workflow DataCleaning --workflow-path /home/jogirodolle/save/CAPTURE_PIPELINES_SNAKEMAKE --config-file CONFIG/config_DataCleaning.yml --cluster-config CONFIG/cluster_config_Slurm_DataCleaning.yml --jobs 20 --job-scheduler SLURM```  


&nbsp;
 
![](https://github.com/BioInfo-GE2POP-BLE/CAPTURE_PIPELINES_SNAKEMAKE/blob/main/readme_img/DataCleaning_4elements.png?raw=true)



## How to use the DATA_CLEANING workflow
 
1) [Prepare your input data](#1-prepare-your-input-data)  
2) [Clone our GitHub repository](#2-clone-our-github-repository)  
3) [Prepare the CONFIG files](#3-prepare-the-config-files)  
4) [Launch the analysis](#4-launch-the-analysis)  
5) [Expected outputs](#5-expected-outputs)



### 1/ Prepare your input data

The input data must be sequences from an Illumina sequencer (Miseq / Hiseq).  

Input sequences can be multiplexed:  
- single-end sequences (SE): you must provide one fastq file named in the format \*name\*.fastq.gz  
- paired-end sequences (PE): you must provide two fastq files named in the format \*name\*_R1.fastq.gz and \*name\*_R2.fastq.gz  

or already demultiplexed:  
- single-end sequences (SE): you must provide one fastq file per sample named in the format \*sample\*.fastq.gz  
- paired-end sequences (PE): you must provide two fastq files per sample named in the format \*sample\*.R1.fastq.gz and \*sample\*.R2.fastq.gz  
The demultiplexed sequences must be placed together in a folder to be specified in the config_file.txt.  


### 2/ Clone our GitHub repository

The CAPTURE_SNAKEMAKE_WORKFLOWS folder must be fully copied in a workspace/storage of your choice.  
For example, you can clone the our repository with:  
```git clone git@github.com:BioInfo-GE2POP-BLE/CAPTURE_PIPELINES_SNAKEMAKE.git```   

    
### 3/ Prepare the config files

The DATA_CLEANING workflow will need information about the dataset and the analysis parameters to perform its different steps.  
These information are provided through two files: *cluster_config_DataCleaning.yml* and *config_DataCleaning.yml*.  
If you name them exactly as written above and place them in a folder named 'CONFIG', the bash launching script will detect them automatically. Otherwise, you will have to pass them as arguments with --config and --cluster-config (see [below](#4-launch-the-analysis) for details).

#### *cluster_config_DataCleaning.yml file:*
This file will be needed if you run the workflow on a computer cluster and want Snakemake to submit jobs. You <ins>only need to modify the partitions or queues names</ins> to match those of your cluster. The first section of the file gives the default values for the job-scheduler's parameters that Snakemake should use for all its steps (or rules). The following sections correspond to specific Snakemake steps, with new parameters values to overwrite the defaults. If you want to assign a different partition/queue for a specific step that does not yet have its own section, you can create a new section for it, preceded by a comma:  

	specificStepName:
    	q or partition: {partitionNameForSpecificStep}

You will find [the list of the steps names](#list-of-the-snakefile-rules) along with what they do and the tools they use at the end of this page.  
Our workflows support SGE and Slurm job-schedulers. <ins>You will find cluster-config files for both in the EXAMPLE/CONFIG folder</ins>.  

&nbsp;

#### *config_DataCleaning.yml file:*  
This file is used to pass all the information and tools parameters that will be used by the DATA_CLEANING workflow. The workflow expects it to contain a specific list of variables and their assigned values, organized in YAML format. Expected variables are:  

**GENERAL VARIABLES**  
- *PAIRED_END:*&nbsp;&nbsp;&nbsp;Whether your data is paired-end or single-end [TRUE or FALSE]  

**INPUT FILES**  
- *FASTQ:*&nbsp;&nbsp;&nbsp;Path to the raw data fastq.gz file (for single-end AND multiplexed data only, otherwise leave blank: "")  
- *FASTQ_R1:*&nbsp;&nbsp;&nbsp;Path to the R1 raw data fastq.gz file, name format must be: name_R1.fastq.gz (for paired-end AND multiplexed data only, otherwise leave blank: "")  
- *FASTQ_R2:*&nbsp;&nbsp;&nbsp;Path to the R2 raw data fastq.gz file, name format must be: name_R2.fastq.gz (for paired-end AND multiplexed data only, otherwise leave blank: "")  
- *DEMULT_DIR:*&nbsp;&nbsp;&nbsp;Path to the folder containing the demultiplexed input files (for demultiplexed data only, otherwise leave blank: ""). Fastq files in the DEMULT_DIR folder must have the following name format: sampleX.R1.fastq.gz and sampleX.R2.fastq.gz for paired-end data; sampleX.fastq.gz for single-end data.  
- *BARCODE_FILE:*&nbsp;&nbsp;&nbsp;Path to the barcode file (for multiplexed data only otherwise leave blank: ""). See description [below](#barcode-file) for more details.  
- *ADAPTER_FILE:*&nbsp;&nbsp;&nbsp;Path to the adapter file. See description [below](#adapter-file) for more details.  


**DEMULTIPLEXING PARAMETERS** (mandatory if the raw fastq files are multiplexed, otherwise leave blank: "")  
- *DEMULT_THREADS:*&nbsp;&nbsp;&nbsp;Number of threads to be allocated on your cluster for the demultiplexing step with Cutadapt (will be passed to the "--nodes" Cutadapt parameter)  
- *DEMULT_SUBSTITUTIONS:*&nbsp;&nbsp;&nbsp;Fraction of authorized substitutions per barcode (tag). Example: to allow 1 substitution for an 8bp barcode, use '0.15'. (will be passed to the "--substitutions" Cutadapt parameter)  


**TRIMMIG PARAMETERS** (mandatory)  
- *TRIMMING_THREADS:*&nbsp;&nbsp;&nbsp;Number of threads to be allocated on your cluster for the trimming step with Cutadapt (will be passed to the "--nodes" Cutadapt parameter)  
- *TRIMMING_QUAL:*&nbsp;&nbsp;&nbsp;This parameter is used to trim low-quality ends from reads. Example:  If '30': nucleotides with quality score < Q30 (1 chance out of 1000 that the sequenced base is incorrect) will be replaced by N (will be passed to the "--quality_cutoff" Cutadapt parameter)  
- *TRIMMING_MIN_LENGTH:*&nbsp;&nbsp;&nbsp;parameter to indicate the minimum size of the sequences to be kept, after applying the TRIMMING_QUAL parameter (will be passed to the "--minimum_length" Cutadapt parameter)  

&nbsp;

*IN A NUTSHELL*  
**Paired-end vs single-end**  
Expected variables differ for paired-end and single-end data: if PAIRED_END is set to TRUE, both FASTQ_R1 and FASTQ_R2 are expected. If PAIRED_END is set to FALSE, only FASTQ is expected.  

**Demultiplex or multiplexed data**  
Some variables must be left blank (*variable: ""*), depending on whether the raw data is multiplexed or demultiplexed. In case of multiplexed data, DEMULT_DIR must be left blank. In case of demultiplexed data, FASTQ, FASTQ_R1, FASTQ_R2, BARCODE_FILE, DEMULT_THREADS and DEMULT_SUBSTITUTIONS must be left blank.

<ins>Examples of config_DataCleaning.yml files adapted to each case can be found in the EXAMPLE/CONFIG folder</ins>.  

&nbsp;

#### *Barcode file:*  
This file must provide the barcode sequences specific to each sample (only required if the data is multiplexed).  

- For paired-end sequencing:  
Three-column file, specifying samples names (column 1), sequences of barcodes for read 1 (P5) (column 2) and sequences of barcodes for read 2 (P7) (column 3).  
Example (no header, tab-separated):  

	```
	Tc2208a	AGCGCA	AGCGCA  
	Tc2235a	CTCAGC	CTCAGC  
	Tc2249a	TAGATC	TAGATC  
	```  

- For single-end sequencing:  
Two-column file, specifying samples names (column 1), and sequences of barcodes (column 2)  
Example (no header, tab-separated):  
	```
	Tc2208a	AGCGCA  
	Tc2235a	CTCAGC  
	Tc2249a	TAGATC  
	```

&nbsp;

#### *Adapter file:*  

This file is used for the trimming step, which removes unwanted technical sequences remaining in the reads. These sequences appear when biological fragments are shorter than expected: in such cases, the whole biological fragment is sequenced from one end to the other, and the sequencer reaches the technical adapter sequence on the 3' end of the fragment, adding its sequence (or part of it) at the end of the read. This technical part of the sequenced read then need to be removed, which is what Cutadapt does in our workflow.  

The adapter file must provide, for each sample, the expected technical sequences that may have been accidentally sequenced. They must be given in the 5'-3' reading direction, as they are expected to be sequenced following the biological sequence part of the read.  

Illumina adapters and index i5/i7 sequences are available in [this document](https://support-docs.illumina.com/SHARE/AdapterSeq/illumina-adapter-sequences.pdf).


**Example for paired-end sequencing:**

![fragment_structure](https://github.com/BioInfo-GE2POP-BLE/CAPTURE_PIPELINES_SNAKEMAKE/blob/main/readme_img/DataCleaning_FragmentStructure.jpg)


Technical sequence to look for and remove at the 3' end of R1 reads (given in 5'-3' reading direction):  

	[barcode7revcomp]AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC[index7]ATCTCGTATGCCGTCTTCTGCTTG  
	
Technical sequence to look for and remove at the 3' end of R2 reads (given in 5'-3' reading direction):  

	[barcode5revcomp]AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT[index5revcomp]GTGTAGATCTCGGTGGTCGCCGTATCATT  


- _For paired-end sequencing_:  
Three-column file specifying the samples names (column 1), technical sequences to look for and remove in R1 (column 2) and technical sequences to look for and remove in R2 (column 3)  
	Example (no header, tab-separated):  

	```
	Tc2208a	TGCGCTAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA	TGCGCTAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTGGCCGTATCATTA  
	Tc2235a	GCTGAGAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA	GCTGAGAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTGGCCGTATCATTA  
	Tc2249a	GATCTAAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA	GATCTAAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTGGCCGTATCATTA  
	```
	
- _For single-end sequencing_:  
Two-column file specifying the samples names (column 1) and technical sequences to look for and remove in reads (column 2)  
	Example (no header, tab-separated):  

	```
	Tc2208a	TGCGCTAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA  
	Tc2235a	GCTGAGAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA  
	Tc2249a	GATCTAAGATCGGAAGAGCACACGTCTGAACTCCAGTCACGTCCGCATCTCGTATGCCGTCTTCTGCTTGA  
	```

### 4/ Launch the analysis

**Environment**  
You can run this workflow on a computer or on a computer cluster. You will need Snakemake and Conda to be available.

**Launching**  
To launch the DATA_CLEANING workflow, you can use our launching script runSnakemakeWorkflow.sh with the option --workflow DataCleaning:  
```./runSnakemakeWorkflow.sh --workflow DataCleaning --workflow-path PATH/TO/CAPTURE_SNAKEMAKE_WORKFLOWS```  

For more help on how to use it, see our GitHub's general README file or run:  
```./runSnakemakeWorkflow.sh --help --workflow-path PATH/TO/CAPTURE_SNAKEMAKE_WORKFLOWS```  

**Notes on Conda**  
The workflow will download and make available the [tools it needs](#tools) through Conda, which means you do not need to have them installed in your working environment behorehand.  
When called for the first time, the DATA_CLEANING Snakemake workflow will download the tools' packages in a pkgs_dirs folder, and install them in a conda environment that will be stored in a .snakemake/conda folder, in the directory you called the workflow from. Every time you call the workflow from a new directory, the Conda environment will be generated again.  

The pkgs_dirs folder however is common to your whole system or cluster personnal environment. Conda's default behaviour is to create it in your home directory, in a .conda folder. If your home space is limited or if you do not have the right to write there from your cluster's nodes, you will need to tell Conda to store its packages somewhere else, thanks to a .condarc file. Place it in your home folder and specify the directory path where you want Conda to store the packages, following this example:  
```
envs_dirs:  
    - /home/username/path/to/appropriate/folder/env  
pkgs_dirs:  
    - /home/username/path/to/appropriate/folder/pkgs  
```

### 5/ Expected outputs  
the workflow create a directory "DATA_CLEANING" in the "WORKFLOWS_OUTPUTS" directory. This directory contained:
- RAWDATA directory
    - REPORTS directory 
        - html file(s) allowing to visualize the quality of the raw reads before cleanning (fastQC)
        - Reads_Count_RawData.txt containing the number of reads per initial fastq.gz file (illumina sequencer)
- DEMULT directory (if the data is multiplexed using barcode)
     - fastq.gz files by samples after demultiplexing (sample1.R1.fastq.gz + sample1.R2.fastq.gz ) and unassigned reads in "unknown" files.
     - REPORTS directory
         - Reads_Count_Demult.txt containing the number of reads per sample contains fastq.gz files after demultiplexing.
         - CUTADAPT_INFOS directory 
             - demultiplexing_cutadapt.info containing cutadapt demultiplexing informations, for each barcode.
- DEMULT_TRIM directory
     - fastq.gz files by samples after trimming (sample1_trimmed.R1.fastq.gz + sample1_trimmed.R2.fastq.gz) 
     - REPORTS directory
         - Reads_Count_DemultTrim.txt containing the number of reads per sample contains fastq.gz files after trimming.
         - CUTADAPT_INFOS directory containing a cutadapt trimming report by sample
         - FASTQC directory containing a html file (and the .zip file) by sample, to visualize the quality of reads after trimming (fastQC).
         - multiQC_Trimming_Report.html (and the directory associated) graphic report based on fastQC and cutadapt reports to visualize the quality of reads after trimming.
- multiQC_DataCleaning_Overall_Report.html (and the directory associated) graphic report based on raw data and trimming fastQC reports to visualize the impact of DATA_CLEANING. 
     

## Tools
This workflow uses the following tools: 
- [Cutadapt v3.5](https://cutadapt.readthedocs.io/en/v3.5/)
- [FastQC v11.9](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) 
- [MultiQC v1.11](https://github.com/ewels/MultiQC/releases)
 
These tools are loaded in a CONDA environment from the conda-forge and bioconda channels.

##  List of the snakefile rules
Name, description and tools used for each of the snakemake workflow rules:

| **Rule name**              | **Description**                                                            | **Tools** |
|:--------------------------:|:--------------------------------------------------------------------------:|:---------:|
| Fastqc_RawFastqs           | Runing FastQC on raw fastq files                                           | FastQC    |
| CountReads_RawFastqs       | Counting reads in raw fastq files                                          |           |
| Demultiplex_RawFastqs      | Demultiplexing raw fastq files                                             | Cutadapt  |
| CountReads_DemultFastqs    | Counting reads in demultiplexed fastq files                                |           |
| Trimming_DemultFastqs      | Trimming demultiplexed fastq files                                         | Cutadapt  |
| CountReads_TrimmedFastqs   | Counting reads in trimmed fastq files                                      |           |
| Fastqc_TrimmedFastqs       | Runing FastQC on trimmed fastq files                                       | FastQC    |
| MultiQC_TrimmedFastqs      | Runing MultiQC on trimmed fastq files                                      | MultiQC   |
| Concatenate_TrimmedFastqs  | Concatenating all trimmed fastq files to compute global quality statistics |           |
| Fastqc_ConcatTrimmedFastqs | Runing FastQC on concatenated trimmed fastq files                          | FastQC    |
| MultiQC_Global             | Runing MultiQC on raw and concatenated trimmed fastq files                 | MultiQC   |


