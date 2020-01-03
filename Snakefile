# This is a 3'UTR APA events analysis workflow by DaPars
# DaPars will use the extracted distal APA sites to infer the proximal APA sites based on the alignment wiggle files of two groups of samples.
    # It contains:
        # 1. Region annotation generation
        # 2. Main function of Dapars
# Here, the first line in the sample_list.txt will be assigned to group1 as tumor/treatment group. 
# The second line will be assigned to group2 as normal/control group. 

# Author: PJ Wu
# Last updata: 2020-01-03

WHOLE_GENE_MODEL="hg38_refseq_whole_gene.bed"
TRANSCRIPTS_TO_SYMBOL="hg38_refseq_id_UCSC.txt"

with open("sample_list.txt", "r") as f:
    SAMPLE_LS=f.readlines();

SAMPLE_LS=[i.strip("\n") for i in SAMPLE_LS]
GROUP1_sample=SAMPLE_LS[0].split(",")
GROUP2_sample=SAMPLE_LS[1].split(",")
SAMPLE=GROUP1_sample + GROUP2_sample

CONDITION=["group1", "group2"]


rule all:
    input:
        "DaPars_result/3UTR_All_Prediction_Results.txt"


rule bamTobedgraph:
    input:
        "rnaseq/mapped_reads/{sample}_sorted.bam"

    output:
       "bed/{sample}.bedgraph"

    shell:
        "genomeCoverageBed -bg -ibam {input} -split > {output}"


rule generate_region_annotation:
    input:
        gene_model=WHOLE_GENE_MODEL,
        gene_symbol=TRANSCRIPTS_TO_SYMBOL

    output:
        "Extracted_3UTR.bed"

    message:
        "Start extracting region annotation..."
    
    shell:
        "python src/DaPars_Extract_Anno.py -b {input.gene_model} -s {input.gene_symbol} -o {output}"


rule make_config_file:
    input:
        utr="Extracted_3UTR.bed",
        bed=expand("bed/{sample}.bedgraph", sample=SAMPLE)
    
    output:
        "config_file"

    run:
        group1=""
        group2=""
        
        for i in input.bed:
            name=str(i)[4:-9]
            if name in GROUP1_sample:
                group1=group1+i+","
            else:
                group2=group2+i+","
        
        group1=group1.strip(",")
        group2=group2.strip(",")
        
        with open(output[0], "w") as f:
            print("# The following file is the result of generate_region_annotation", file=f)
            print("Annotated_3UTR="+str(input.utr), file=f)
            
            print("# A comma-separated list of Bedgraph files of samples from condition 1", file=f)
            print("Group1_Tophat_aligned_Wig="+group1, file=f)
            print("# A comma-separated list of Bedgraph files of samples from conditon 2", file=f)
            print("Group2_Tophat_aligned_Wig="+group2, file=f)
            print("# Export default setting", file=f)
            
            print("Output_directory=DaPars_result/\nOutput_result_file=3UTR", file=f)
            print("At least how many samples passing the coverafe threshold in two conditions\nNum_least_in_group1=1\nNum_least_in_group2=1", file=f)
            print("# Cutoff for coverage, FDR of P-value from Fisher exact test", file=f)
            print("Coverage_cutoff=30\nFDR_cutoff=0.05\nPDUI_cutoff=0.5\nFold_change_cutoff=0.59", file=f)


rule dapars_main:
    input:
        "config_file"
    output:
        "DaPars_result/3UTR_All_Prediction_Results.txt"
    shell:
        "python src/DaPars_main.py {input}"

