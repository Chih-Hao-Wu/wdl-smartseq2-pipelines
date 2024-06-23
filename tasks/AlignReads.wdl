version 1.0

task filterSJout {
    meta {
        description: "Filter splice junctions from *.SJ.out.tab file; reduces spurious mapping"
        # decreases runtime, multi-mapped reads
        # limitSjdbInsertNsj=1000000, number of junctions to be inserted on the fly
    }

    input {
        File sj_file
    }

    command {
        set -e

        python src/filterSJout.py ~{sj_file}
        echo $?
    }

    output{
        String out = read_string(stdout())
    }
}

task STAR2PairedEndGetSjdb {
    meta {
        description: "Get *.SJ.out.tab file, does not output SAM/BAM"
    }

    input {
        String star_reference
        File reference_genome
        String input_id
        File trimmed_fastq1_input
        File trimmed_fastq2_input

        String workflow_output_dir
        String write_subdirectory = workflow_output_dir + "mapped/sjdb/"
        
        # runtime values
        Int mem_mb = ceil(size(reference_genome, "Gi")) * 12000
        Int cpus = 6
    }

    command <<<
        set -e

        if [ ! -d ~{write_subdirectory} ];
            then
            mkdir -p ~{write_subdirectory}
        fi

        zcat_option="-"
        if ( file ~{trimmed_fastq1_input} | grep -q compressed );
            then
            zcat_option="zcat"
        fi

        module load STAR/2.7.11b

        STAR \
            --runThreadN ~{cpus} \
            --genomeDir ~{star_reference} \
            --readFilesCommand $zcat_option \
            --readFilesIn ~{trimmed_fastq1_input} ~{trimmed_fastq2_input} \
            --outFileNamePrefix "~{write_subdirectory+input_id}_" \
            --outSAMtype None

        # https://groups.google.com/g/rna-star/c/QxLqZxqOzko/m/EJKk_agACAAJ
        # https://groups.google.com/g/rna-star/c/f4SsgQYTDeM/m/ieVT1a2QBwAJ
    >>>

    runtime{
        memory: "${mem_mb} MiB"
        cpu: cpus
    }

    output {
        File output_sj_tab = "~{write_subdirectory+input_id}_SJ.out.tab"
    }
}

task STARSecondPassPairedEnd {
    meta {
        description: "Aligns reads in paired *.fastq files to reference genome"
    }

    input {
        String star_reference # /path/to/genome/
        File reference_genome
        String input_id
        File trimmed_fastq1_input
        File trimmed_fastq2_input

        String workflow_output_dir   
        String write_subdirectory = workflow_output_dir + "mapped/"

        # runtime values
        Int mem_mb = ceil(size(reference_genome, "Gi")) * 12000
        Int cpus = 6
        # multiply input size by 2.2 to account for output bam file + 20% overhead, add size of reference.
        # the amount of space on disk needed is at least ~3*sizeOfGzippedFastqs.
        # Int disk = ceil((size(reference_genome, "Gi") * 2) + (size(trimmed_fastq1_input, "Gi") * 5.0))
    }

    command <<<
        set -e

        zcat_option="-"
        if ( file ~{trimmed_fastq1_input} | grep -q compressed );
            then
            zcat_option="zcat"
        fi

        module load STAR/2.7.11b

        # one pass
        STAR \
            --runThreadN ~{cpus} \
            --genomeDir ~{star_reference} \
            --readFilesCommand $zcat_option \
            --readFilesIn ~{trimmed_fastq1_input} ~{trimmed_fastq2_input} \
            --outFileNamePrefix "~{write_subdirectory+input_id}_" \
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
        memory: "${mem_mb} MiB"
        cpu: cpus
        #disk: disk + " GB"
    }
    
    output {
        File output_bam = "~{write_subdirectory+input_id}_Aligned.sortedByCoord.out.bam"
    }
}


