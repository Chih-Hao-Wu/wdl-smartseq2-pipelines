version 1.0

task trimAdapters {
    meta {
        description: "Trim 3' adapters from *.fastq files"
    }

    input {
        String adapter_string
        Array[File] fastq
        String fastq1_out_filename = sub(sub(fastq[0], "\\..*$", ""), "^.*/", "")
        String fastq2_out_filename = sub(sub(fastq[1], "\\..*$", ""), "^.*/", "")

        String workflow_output_dir   
        String write_subdirectory = workflow_output_dir + "fastq/"

        # runtime values
        Int cpu = 1
        Int mem_mb = 1908 # ~2 GB
    }

    command <<<
        set -e
        
        if [ ! -d "~{write_subdirectory}" ];
            then
            mkdir ~{write_subdirectory}
        fi 

        # standardise file extension
        function standardise_file_extension {
            local path_to_file=$1
            local compressed=$2

            if $compressed;
                then
                new_file_name="${path_to_file%%.*}.fastq.gz"
            else
                new_file_name="${path_to_file%%.*}.fastq"
            fi

            mv "$path_to_file" "$new_file_name"
            echo $new_file_name
        }

        is_compressed=false

        if ( file ~{fastq[0]} | grep -q compressed );
            then
            is_compressed=true
        fi
        
        fq1=$(standardise_file_extension ~{fastq[0]} $is_compressed)
        fq2=$(standardise_file_extension ~{fastq[1]} $is_compressed)

        module load trimgalore/0.6.7

        trim_galore \
            -j ~{cpu} \
            --output_dir ~{write_subdirectory} \
            --paired \
            --adapter ~{adapter_string} \
            $fq1 \
            $fq2

    >>>

    runtime {
        #docker: docker
        memory: "${mem_mb} MiB"
        cpu: cpu
    }

    output {
        File trimmed_fastq1_input = "~{write_subdirectory+fastq1_out_filename}_val_1.fq.gz"
        File trimmed_fastq2_input = "~{write_subdirectory+fastq2_out_filename}_val_2.fq.gz"
    }

}
