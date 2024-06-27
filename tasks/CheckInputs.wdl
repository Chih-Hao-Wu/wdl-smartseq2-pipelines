version 1.0

task checkInputArrays {
    input {
        Array[String] labels
        Pair[Array[File], Array[File]] fastqPairedFiles
        String workflowOutputDir 

        Int nSamples = length(labels)
    }

    command <<<
        set -e

        declare -a arr_fq1=(~{sep=' ' fastqPairedFiles.left})
        declare -a arr_fq2=(~{sep=' ' fastqPairedFiles.right})
        declare -a suffixes=("" "")
    
        if ( ~{nSamples} != ${#arr_fq1[@]} || ~{nSamples} != ${#arr_fq2[@]} ); then
           echo "ERROR: Different number of labels to *.fastq.gz files were provided"
           exit 1;
        fi    
    
        combined_array=("${arr_fq1[0]}" "${arr_fq2[0]}")

        function get_suffix {
            local full_string=$1
            local prefix=$2

            local basename="$(basename ${full_string%%.*})"
            echo "${basename#$prefix}"
        }

        for (( i=0; i<~{nSamples}; ++i )); do
            if (( i==0 )); then
                for (( j=0; j<${#combined_array[@]}; ++j )); do
                    suffixes[$j]="$(get_suffix "${combined_array[$j]}" "~{labels[0]}")"
                done
            fi

            fq1="${arr_fq1[$i]}"
            fq2="${arr_fq2[$i]}"

            if [ "${fq1/${suffixes[0]}/}" != "${fq2/${suffixes[1]}/}" ]; then
                echo "ERROR: Different labels than provided for either or both *.fastq.gz files"
                exit 1;
            fi
        done

        if [ ! -d ~{workflowOutputDir} ]; then
            mkdir ~{workflowOutputDir}
        fi

        echo "${suffixes[0]}" > "~{workflowOutputDir}suffixes.txt"
        echo "${suffixes[1]}" >> "~{workflowOutputDir}suffixes.txt"
    >>>

    output {
        Array[String] suffixes = read_lines("~{workflowOutputDir}suffixes.txt")
    }
}