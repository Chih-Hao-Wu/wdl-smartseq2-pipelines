version 1.0

task checkInputPaired {
    meta {
        description: "Assert that two *.fastq files are provided"
    }

    input {
        Array[File] fastq
    }

    Int len_fastq_inputs = length(fastq)

    command <<<
        set -e

        declare -a fastq_inputs=(~{sep=' ' fastq})

        if (( ~{len_fastq_inputs} != 2 )); 
            then
            echo "ERROR: Other number than (2) *.fastq files were provided"
            exit 1;
        fi

        # localisation error is checked by default
        for (( i=0; i<${#fastq_inputs[@]}; ++i ));
            do
            if ! test ${fastq_inputs[$i]};
                then
                echo "ERROR: File \"${fastq_inputs[$i]}\" does not exist"
                exit 1;
            fi
            done;

        echo 0;
    >>>

}
