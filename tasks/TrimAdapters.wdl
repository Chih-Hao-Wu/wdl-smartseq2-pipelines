version 1.0

task trimAdapters {
    meta {
        description: "Trim 3' adapters from *.fastq files"
    }

    input {
        String adapterString
        String label
        Array[File] fastq
        Array[String] suffixes
        String workflowOutputDir

        # runtime arguments
        Int alloc_cpu = 1
        Int alloc_mem_mb = 1908 # MiB
    }

    command <<<
        set -e

        # standardise file extension
        function standardise_file_extension {
            local path_to_file=$1
            local compressed=$2

            if $compressed; then
                replace_file="${path_to_file%%.*}.fastq.gz"
            else
                replace_file="${path_to_file%%.*}.fastq"
            fi
            
            mv ${path_to_file} ${replace_file}
            echo $replace_file
        }

        is_compressed=false

        if ( file ~{fastq[0]} | grep -q compressed );
            then
            is_compressed=true
        fi
        
        fq1=$(standardise_file_extension ~{fastq[0]} $is_compressed)
        fq2=$(standardise_file_extension ~{fastq[1]} $is_compressed)

        echo $fq1
          
        module load trimgalore/0.6.7

        trim_galore \
            -j ~{alloc_cpu} \
            --output_dir ~{workflowOutputDir} \
            --paired \
            --adapter ~{adapterString} \
            $fq1 \
            $fq2
    >>>

    runtime {
        memory: "${alloc_mem_mb} MiB"
        cpu: alloc_cpu
    }

    output {
        File trimmedFastqInput1 = "~{workflowOutputDir+label+suffixes[0]}_val_1.fq.gz"
        File trimmedFastqInput2 = "~{workflowOutputDir+label+suffixes[1]}_val_2.fq.gz"
    }
}
