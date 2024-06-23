version 1.0

import "tasks/CheckInputs.wdl" as CheckInputs
import "tasks/TrimAdapters.wdl" as TrimAdapters
import "tasks/AlignReads.wdl" as AlignReads

workflow SingleSampleSmartSeq2 {
    meta {
        description: "always paired end"
        allowNestedInputs: true
    }

    String pipeline_version = "0.1.0"
    
    input {
        # properties
        Boolean paired_end = true
        Boolean stranded = false
        String adapter_string
        
        # samples
        String star_reference
        File reference_genome
        String input_id
        Array[File]+ fastq
    }

    if (paired_end) {
        call CheckInputs.checkInputPaired as checkInputPaired {
            input:
                fastq = fastq
        }
    }

    String workflow_output_dir = "/data/CDSLSahinalp/chihhao/cromwell/smartseq2_single_sample/workflow-outputs/"

    call TrimAdapters.trimAdapters as trimAdapters {
        input:
            adapter_string = adapter_string,
            fastq = fastq,
            workflow_output_dir = workflow_output_dir
    }

    call AlignReads.STAR2PassPairedEnd as STAR2PassPairedEnd {
        input:
            star_reference = star_reference,
            reference_genome = reference_genome,
            input_id = input_id,
            trimmed_fastq1_input = trimAdapters.trimmed_fastq1_input,
            trimmed_fastq2_input = trimAdapters.trimmed_fastq2_input,
            workflow_output_dir = workflow_output_dir
    }
}
