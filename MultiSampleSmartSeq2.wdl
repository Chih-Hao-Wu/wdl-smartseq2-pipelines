version 1.0

import "tasks/CheckInputs.wdl" as CheckInputs
import "tasks/TrimAdapters.wdl" as TrimAdapters
import "tasks/AlignReads.wdl" as AlignReads

workflow MultiSampleSmartSeq2 {
    meta {
        description: "multiple samples of SmartSeq2 data"
                     # two pass, STAR alignment
                     # -> *.bam and files for differential gene expression analysis
        allowNestedInputs: true
    }

    String pipeline_version = "0.1.0"

    input {
        # properties
        #Boolean two_pass = true
        String adapterString

        # samples
        String referenceStarIndex
        File referenceGenome
        Array[String] labels
        Pair[Array[File], Array[File]] fastqPairedFiles
    }

    String workflowOutputDir = "/Users/wuchh/project/cromwell/wdl-smartseq2-pipelines/workflow-outputs/"

    # check arrays
    call CheckInputs.checkInputArrays as checkInputArrays {
        input:
            labels = labels,
            fastqPairedFiles = fastqPairedFiles,
            workflowOutputDir = workflowOutputDir
    }

    call createWorkflowSubdirectory {
        input:
            workflowOutputDir = workflowOutputDir,
            subdirectoryNames = ["fastq/", "mapped/", "mapped/sjdb/"]
    }

    scatter (i in range(length(labels))) {
        call TrimAdapters.trimAdapters as trimAdapters {
            input:
                adapterString = adapterString,
                label = labels[i],
                fastq = [fastqPairedFiles.left[i], fastqPairedFiles.right[i]],
                suffixes = checkInputArrays.suffixes,
                workflowOutputDir = workflowOutputDir + "fastq/"
        }

        call AlignReads.STARGetSjdbPairedEnd as STAR2PairedEndGetSjdb{
            input:
                referenceStarIndex = referenceStarIndex,
                referenceGenome = referenceGenome,
                label = labels[i],
                fastq1 = trimAdapters.trimmedFastqInput1,
                fastq2 = trimAdapters.trimmedFastqInput2,
                workflowOutputDir = workflowOutputDir + "mapped/sjdb/"
        }
        
        call AlignReads.STARTwoPassPairedEnd as STARTwoPassPairedEnd {
            input:
                referenceStarIndex = referenceStarIndex,
                referenceGenome = referenceGenome,
                label = labels[i],
                fastq1 = trimAdapters.trimmedFastqInput1,
                fastq2 = trimAdapters.trimmedFastqInput2,
                workflowOutputDir = workflowOutputDir + "mapped/"
        }
    }

    # merge *.SJ.out.tab and map
}

task createWorkflowSubdirectory {
    input {
        String workflowOutputDir
        Array[String] subdirectoryNames
    }

    command <<<
        set -e

        declare -a subdirNames=(~{sep=' ' subdirectoryNames})

        for subdirectoryName in "${subdirNames[@]}"; do
            if [ ! -d "~{workflowOutputDir}${subdirectoryName}" ]; then
                mkdir "~{workflowOutputDir}${subdirectoryName}"
            fi
        done
    >>>
}

    # merge *.SJ.out.tab and map
    #call AlignReads.concatSpliceJunctions as concatSpliceJunctions {
    #     input:
    #         sj_files = sj_files
    # }

    # scatter (fastq in fastq_paired_files) {
    #     call singleSample.SingleSampleSmartSeq2 as SingleSampleSmartSeq2 {
    #         input:
    #             fastq = fastq
    #     }
    # }

    # HaplotypeCaller

    # variant filtering
#}