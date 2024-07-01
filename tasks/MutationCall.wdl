version 1.0

task HaplotypeCallerGvcf {
    input {
        String workflowOutputDir
        String bamFileIn
        String dbSNPFile
        String label
        String gvcfFileOut = label+".g.vcf"

        # runtime arguments
        Int alloc_cpu = 1
        Int alloc_mem_gb = 64
    }

    command <<<
        set -e

        module load GATK/4.5.0.0

        referenceGenomeString="/data/CDSLSahinalp/chihhao/reference/grcm39/release-m35/GRCm39.primary_assembly.genome.fa"

        gatk --java-options "-Xmx~{alloc_mem_gb}g" HaplotypeCaller \
            -R $referenceGenomeString \
            -I ~{bamFileIn} \
            -O "~{workflowOutputDir}~{gvcfFileOut}" \
            --dont-use-soft-clipped-bases false \
            --standard-min-confidence-threshold-for-calling 20 \
            --dbsnp ~{dbSNPFile} \
            -ERC GVCF
    >>>

    runtime {
        memory: "${alloc_mem_gb} G"
        cpu: alloc_cpu
    }

    output {
        File outputGvcf = "~{workflowOutputDir}~{gvcfFileOut}"
    }
}
