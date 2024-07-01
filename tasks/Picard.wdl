version 1.0

task addOrReplaceReadGroups {
    meta {
        description: "Assigns all the reads in a file to a single new read-group"
    }

    input {
        String label
        String workflowOutputDir
        File bamFileIn
        String bamFileOut = sub(basename(bamFileIn), ".bam", ".rg.bam")
        String readGroupPlatform = "NOVASEQ"

        # runtime arguments
        Int alloc_cpu = 1
        Int alloc_mem_mb = 2000
    }

    command <<<
        set -e

        module load picard/3.2.0

        java -Xmx"~{alloc_mem_mb}m" -jar $PICARDJARPATH/picard.jar AddOrReplaceReadGroups \
            I=~{bamFileIn} \
            O="~{workflowOutputDir}~{bamFileOut}" \
            RGID=0 \
            RGPL=~{readGroupPlatform} \
            RGLB=lib1 \
            RGPU=group1 \
            RGSM=~{label} 
    >>>
    
    runtime {
        memory: "${alloc_mem_mb} MiB"
        cpu: alloc_cpu
    }

    output {
        File outputReadGroupsBam = "~{workflowOutputDir}~{bamFileOut}"
    }
}

task markDuplicates {
    meta {
        description: "Duplicate reads are flagged with the hexadecimal value of 0x0400"
    }

    input {
        String workflowOutputDir
        String label
        File bamFileIn
        String bamFileOut = sub(basename(bamFileIn), ".rg.bam", ".mark_dupl.bam")

        # runtime arguments
        Int alloc_cpu = 1
        Int alloc_mem_mb = 2000
    }

    command <<<
        set -e

        module load picard/3.2.0

        java "-Xmx~{alloc_mem_mb}m" -jar $PICARDJARPATH/picard.jar MarkDuplicates \
            VALIDATION_STRINGENCY=SILENT \
            I=~{bamFileIn} \
            O="~{workflowOutputDir}~{bamFileOut}" \
            M="~{workflowOutputDir}~{label}_metrics.txt"
    >>>
    
    runtime {
        memory: "${alloc_mem_mb} MiB"
        cpu: alloc_cpu
    }

    output {
        File outputMarkDuplBam = "~{workflowOutputDir}~{bamFileOut}"
        File outputMarkDuplMetrics = "~{workflowOutputDir}~{label}_metrics.txt"
    }
}

task splitNCigarStrings { 
    meta {
        description: "Split reads with N in cigar string, spanning splicing events"
    }

    input {
        String workflowOutputDir
        String label
        File bamFileIn
        String bamFileOut = sub(basename(bamFileIn), ".mark_dupl.bam", ".spl_cig.bam")
        #File referenceGenome

        # runtime arguments
        Int alloc_cpu = 1
        Int alloc_mem_gb = 32
    }

    command <<<
        set -e

        module load GATK/4.5.0.0

        referenceGenomeString="/data/CDSLSahinalp/chihhao/reference/grcm39/release-m35/GRCm39.primary_assembly.genome.fa"
        
        gatk --java-options "-Xmx~{alloc_mem_gb}g" SplitNCigarReads \
            -R $referenceGenomeString \
            -I ~{bamFileIn} \
            -O "~{workflowOutputDir}~{bamFileOut}" \
            --skip-mapping-quality-transform false     
    >>>
    
    runtime {
        memory: "${alloc_mem_gb} G"
        cpu: alloc_cpu
    }

    output {
        File outputSplCigBam = "~{workflowOutputDir}~{bamFileOut}"
    }
}

task baseScoreRecal {
    input {
        String workflowOutputDir
        String label
        File bamFileIn
        Array[String] knownSitesFiles
        Int nKnownSites = length(knownSitesFiles)

        # runtime arguments
        Int alloc_cpu = 1
        Int alloc_mem_gb = 32
    }

    command <<<
        set -e
        
        module load GATK/4.5.0.0

        declare -a sitesFiles=(~{sep=' ' knownSitesFiles})
        knownSitesString=""

        for (( i=0; i<~{nKnownSites}; ++i )); do
            knownSitesString+="--known-sites ${sitesFiles[$i]} "
        done

        referenceGenomeString="/data/CDSLSahinalp/chihhao/reference/grcm39/release-m35/GRCm39.primary_assembly.genome.fa"

        gatk --java-options "-Xmx~{alloc_mem_gb}g" BaseRecalibrator \
            -R $referenceGenomeString \
            -I ~{bamFileIn} \
            -O "~{workflowOutputDir}~{label}_recal_data.table" \
            $knownSitesString 
    >>>

    runtime {
        memory: "${alloc_mem_gb} G"
        cpu: alloc_cpu
    }        

    output {
        File outputRecalTable = "~{workflowOutputDir}~{label}_recal_data.table"
    }    
}

task applyBaseScoreRecal {
    input {
        String workflowOutputDir
        File bamFileIn
        File recalTable
        String bamFileOut = sub(basename(bamFileIn), ".spl_cig.bam", ".recal.bam")

        # runtime arguments
        Int alloc_cpu = 1
        Int alloc_mem_gb = 3
    }

    command <<<
        set -e

        module load GATK/4.5.0.0

        referenceGenomeString="/data/CDSLSahinalp/chihhao/reference/grcm39/release-m35/GRCm39.primary_assembly.genome.fa"

        gatk --java-options "-Xmx~{alloc_mem_gb}g" ApplyBQSR \
            -R $referenceGenomeString \
            -I ~{bamFileIn} \
            --bqsr-recal-file ~{recalTable} \
            -O "~{workflowOutputDir}~{bamFileOut}"
    >>>

    runtime {
        memory: "${alloc_mem_gb} G"
        cpu: alloc_cpu
    }

    output {
        String outputRecalBamFilename = "~{workflowOutputDir}~{bamFileOut}" # necessary for passing auxillary index `*.bai`
        File outputRecalBam = "~{workflowOutputDir}~{bamFileOut}"
    }
}
