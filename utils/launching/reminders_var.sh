# all
workflow_help=$(grep -e "^--workflow " ${checks_path}/launcher_help.txt)
config_file_help=$(grep -e "^--config-file " ${checks_path}/launcher_help.txt)
cluster_profile_help=$(grep -e "^--cluster-profile " ${checks_path}/launcher_help.txt)
all_PAIRED_END_msg="PAIRED_END: set to TRUE in case of paired end data (R1 + R2), to FALSE in case of single end data."
all_yaml_msg="Variables must be specified in the yaml format, with one variable per row, followed by a ':' and a space before the assigned value, for example : VARIABLE_NAME: value.\nSome variables can be left empty, for example: VARIABLE_NAME: \"\" "

# DC
DC_UMI_msg="UMI: Wether or not UMI sequences should be extracted from reads. Set to TRUE if UMIs were incorporated during library construction. This option is currently only supported for demultiplexed data. [TRUE or FALSE]"

# RM
RM_PAIRED_END_msg="PAIRED_END: set to TRUE in case of paired end data (R1 + R2), to FALSE in case of single end data."
RM_bed_msg="The provided bed file must have 3 columns separated by tabs. Each row represents a genomic region of interest, with the first column indicating the reference's sequence name, and the second and third columns the starting and ending positions of the region in the sequence."
RM_CREATE_SUB_BAMS_msg="CREATE_SUB_BAMS: set to TRUE in case you provided a bed file AND want to extract the reads mapping onto the specified regions, to FALSE otherwise. If set to TRUE, the extracted reads will be stored in new bams, and a new reference (matching the bams) containing only the bed regions will be created."
RM_MAPPER_msg="MAPPER: the mapper that will be used to map your reads. Currently supported options are 'bwa-mem2_mem', 'bwa_mem', 'bowtie2' and 'minimap2'."
RM_REMOVE_DUP_MARKDUPLICATES_msg="REMOVE_DUP_MARKDUPLICATES: Whether or not to remove duplicates with 'picard MarkDuplicates' after the mapping step. [TRUE or FALSE]"
RM_REMOVE_DUP_UMI_msg="REMOVE_DUP_UMI: Whether or not to remove duplicates with 'umi_tools dedup' after the mapping step. [TRUE or FALSE]"

# VC
VC_BAMS_LIST_msg="BAMS_LIST: The path to the directory containing the mapped bam files and the index file in .bam.bai format."

# VF