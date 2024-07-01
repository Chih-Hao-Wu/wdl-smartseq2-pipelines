version 1.0

import "tasks/CheckInputs.wdl" as CheckInputs
import "tasks/TrimAdapters.wdl" as TrimAdapters
import "tasks/AlignReads.wdl" as AlignReads
import "tasks/Picard.wdl" as Picard
import "tasks/MutationCall.wdl" as MutationCall

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
        Array[String] knownSitesFiles
        Array[String] labels
        Pair[Array[File], Array[File]] fastqPairedFiles
    }

    String workflowOutputDir = "/data/CDSLSahinalp/chihhao/cromwell/smartseq2_single_sample/workflow-outputs/"

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
            subdirectoryNames = ["fastq/", "mapped/", "mapped/sjdb/", "variants/"]
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
    }

    # merge *.SJ.out.tab and map
    call gatherSpliceJunctions {
        input:
            spliceJunctionFiles = STAR2PairedEndGetSjdb.outputSpliceJunction,
            workflowOutputDir = workflowOutputDir + "mapped/sjdb/"
    }

    scatter (i in range(length(labels))) {
        call AlignReads.STARTwoPassPairedEnd as STARTwoPassPairedEnd {
            input:
                referenceStarIndex = referenceStarIndex,
                referenceGenome = referenceGenome,
                label = labels[i],
                fastq1 = trimAdapters.trimmedFastqInput1[i],
                fastq2 = trimAdapters.trimmedFastqInput2[i],
                workflowOutputDir = workflowOutputDir + "mapped/",
                sjdbFile = gatherSpliceJunctions.sjdbConcatenatedFile
        }

        call Picard.addOrReplaceReadGroups as addOrReplaceReadGroups {
            input:
                workflowOutputDir = workflowOutputDir + "mapped/",
                label = labels[i],
                bamFileIn = STARTwoPassPairedEnd.outputSortedBam
        }

        call Picard.markDuplicates as markDuplicates {
            input:
                workflowOutputDir = workflowOutputDir + "mapped/",
                label = labels[i],
                bamFileIn = addOrReplaceReadGroups.outputReadGroupsBam
        }

        call Picard.splitNCigarStrings as splitNCigarStrings {
            input:
                workflowOutputDir = workflowOutputDir + "mapped/",
                label = labels[i],
                bamFileIn = markDuplicates.outputMarkDuplBam
                #referenceGenome = referenceGenome
        }

        call Picard.baseScoreRecal as baseScoreRecal {
            input:
                workflowOutputDir = workflowOutputDir + "mapped/",
                label = labels[i],
                bamFileIn = splitNCigarStrings.outputSplCigBam,
                knownSitesFiles = knownSitesFiles
        }

        call Picard.applyBaseScoreRecal as applyBaseScoreRecal {
            input:
                workflowOutputDir = workflowOutputDir + "mapped/",
                bamFileIn = splitNCigarStrings.outputSplCigBam,
                recalTable = baseScoreRecal.outputRecalTable
        }

        call MutationCall.HaplotypeCallerGvcf as HaplotypeCallerGvcf {
            input:
                workflowOutputDir = workflowOutputDir + "variants/",
                label = labels[i],
                bamFileIn = applyBaseScoreRecal.outputRecalBamFilename,
                dbSNPFile = knownSitesFiles[1]
        }
    }
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

task gatherSpliceJunctions {
    input {
        Array[File] spliceJunctionFiles
        String workflowOutputDir
        String filteredJointFile = workflowOutputDir + "filteredJoint_SJ.out.tab"
    }

    command <<<
        set -e

        >~{filteredJointFile}

        declare -a splJuncFiles=(~{sep=' ' spliceJunctionFiles})
        
        for (( i=0; i<${#splJuncFiles[@]}; ++i )); do
            python /data/CDSLSahinalp/chihhao/cromwell/smartseq2_single_sample/src/filterSpliceJunctions.py ${splJuncFiles[$i]} >> ~{filteredJointFile}
        done
    >>>

    output {
        File sjdbConcatenatedFile = "~{filteredJointFile}"
    }
}
    # Picard

    # HaplotypeCaller

    # variant filtering
#}
