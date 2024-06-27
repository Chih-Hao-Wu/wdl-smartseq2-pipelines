version 1.0

task STARGetSjdbPairedEnd {
    input {
        String referenceStarIndex
        File referenceGenome
        String label
        File fastq1
        File fastq2
        String workflowOutputDir

        # runtime arguments
        Int alloc_cpu = 6
        Int alloc_mem_mb = ceil(size(referenceGenome, "Gi")) * 12000
    }

    command <<<
        set -e

        zcat_option="-"
        if ( file ~{fastq1} | grep -q compressed ); then
            zcat_option="zcat"
        fi

        module load STAR/2.7.11b

        STAR \
            --runThreadN ~{alloc_cpu} \
            --genomeDir ~{referenceStarIndex} \
            --readFilesCommand $zcat_option \
            --readFilesIn ~{fastq1} ~{fastq2} \
            --outFileNamePrefix "~{workflowOutputDir+label}_" \
            --outSAMtype None

        # https://groups.google.com/g/rna-star/c/QxLqZxqOzko/m/EJKk_agACAAJ
        # https://groups.google.com/g/rna-star/c/f4SsgQYTDeM/m/ieVT1a2QBwAJ
    >>>

    runtime {
        memory: "${alloc_mem_mb} MiB"
        cpu: alloc_cpu     
    }

    output {
        File outputSpliceJunction = "~{workflowOutputDir+label}_SJ.out.tab"
    }
}

task STARTwoPassPairedEnd {
    input {
        String referenceStarIndex
        File referenceGenome
        String label
        File fastq1
        File fastq2
        String workflowOutputDir

        # runtime arguments
        Int alloc_cpu = 6
        Int alloc_mem_mb = ceil(size(referenceGenome, "Gi")) * 12000
    }

    command <<<
        set -e

        zcat_option="-"
        if ( file ~{fastq1} | grep -q compressed ); then
            zcat_option="zcat"
        fi

        module load STAR/2.7.11b

        # one pass
        STAR \
            --runThreadN ~{alloc_cpu} \
            --genomeDir ~{referenceStarIndex} \
            --readFilesCommand $zcat_option \
            --readFilesIn ~{fastq1} ~{fastq2} \
            --outFileNamePrefix "~{workflowOutputDir+label}_" \
            --outSAMtype BAM SortedByCoordinate \
            --sjdbInsertSave All \
            --quantMode TranscriptomeSAM GeneCounts \
            --outFilterMultimapNmax 10 \
            --winAnchorMultimapNmax 50 \
            --outSAMprimaryFlag OneBestScore \
            --outMultimapperOrder Random \
            --outSAMmultNmax -1 \
            --outFilterType BySJout
    >>>

    runtime {
        memory: "${alloc_mem_mb} MiB"
        cpu: alloc_cpu     
    }
    
    output {
        File outputSortedBam = "~{workflowOutputDir+label}_Aligned.sortedByCoord.out.bam"
    }
}