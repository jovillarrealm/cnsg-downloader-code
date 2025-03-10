#!/bin/bash

output_dir="./"
prefix='both'
date_format='%d-%m-%Y'
today="$(date +$date_format)"
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
utils_dir="$scripts_dir"utils/

check_api_key() {
    if [[ -z ${api_key+x} ]]; then
        if [ -z "$NCBI_API_KEY" ]; then
            echo "WARNING: NCBI API key cannot be aquired from this environment"
            echo "Please set the NCBI_API_KEY var"
        else
            api_key=$NCBI_API_KEY
            echo "INFO: An NCBI API key can be aquired from this environment"
        fi
    fi
}

check_api_key() {
    if [[ -z ${api_key+x} ]]; then
        if [ -z "$NCBI_API_KEY" ]; then
            echo "WARNING: NCBI API key cannot be acquired from this environment."
            echo "Please set the NCBI_API_KEY environment variable."
        else
            api_key=$NCBI_API_KEY
            echo "INFO: An NCBI API key can be acquired from the NCBI_API_KEY environment variable."
        fi
    fi
}

print_help() {
    local script_name=$(basename "$0")

    echo ""
    echo "Usage: $script_name [OPTIONS] -i TAXON"
    echo ""
    echo "Description:"
    echo "  This script downloads a tsv genomic data summary from NCBI based on a taxon name or ID."
    echo "  It allows filtering by source database, and reference genomes."
    echo "  Requires 'datasets' and 'dataformat' to be in your PATH."
    echo ""
    echo "Required Arguments:"
    echo "  -i, TAXON"
    echo "      Taxon name or NCBI Taxonomy ID to search for."
    echo ""
    echo "Optional Arguments:"
    echo "  -o, OUTPUT_DIR"
    echo "      Path to the directory where GENOMIC*/ folders will be created."
    echo "      (Default: $output_dir)"
    echo ""
    echo "  -a, API_KEY_FILE"
    echo "      Path to a file containing your NCBI API key. If provided, enhances performance."
    echo "      You can obtain an API key from your NCBI account."
    echo ""
    echo "  -p, SOURCE_DB"
    echo "      Chooses between GenBank and RefSeq as the source database."
    echo "      (Default: '$prefix')"
    echo "      Options: GCF (RefSeq), GCA (GenBank), all (includes duplicates), both (prefers RefSeq)"
    echo ""
    echo "  -r, true"
    echo "      Downloads only reference genomes."
    echo ""
    echo "  -l, NUMBER"
    echo "      Limits the summary to the first NUMBER of genomes."
    echo ""
    echo "  -h, "
    echo "      Displays this help message and exits."
    echo ""
    echo "Dependencies:"
    echo "  datasets, dataformat"
    echo ""
    check_api_key # run the function to display api key info.
    echo ""
    echo "NCBI API Key Information:"
    if [[ -z ${api_key+x} ]]; then
        if [ -z "$NCBI_API_KEY" ]; then
            echo "  WARNING: NCBI API key cannot be acquired from this environment."
            echo "  Please set the NCBI_API_KEY environment variable or use the -a option."
        else
            echo "  INFO: An NCBI API key can be acquired from the NCBI_API_KEY environment variable."
        fi
    else
        echo "  INFO: NCBI API key provided via -a option."
    fi
    echo ""
    "$utils_dir"clis_download.sh
}


if [[ $# -lt 2 ]]; then
    print_help
    exit 1
fi

compare_name_and_rename() {
    local variable_name="$download_file"

    # Find files containing "latest" in the specified directory
    local latest_file=$(find "$output_dir" -type f -name "*_latest*tsv" -print -quit)

    if [[ -n "$latest_file" ]]; then
        # Extract the base name of the variable and the file
        local variable_base_name=$(basename "$variable_name")
        local file_base_name=$(basename "$latest_file")

        # Remove "latest" from the file's base name for comparison

        # Compare the base names
        if [[ "$variable_base_name" == "$file_base_name" ]]; then
            # Add your "continue" logic here
            return 0 #success
        else
            # Rename the file to remove "latest"
            local file_base_no_latest=$(echo "$file_base_name" | sed 's/_latest//g')
            local new_file_name=$(dirname "$latest_file")/$file_base_no_latest
            mv "$latest_file" "$new_file_name"
            echo "Renamed '$latest_file' to '$new_file_name'."
            return 1 #Renamed
        fi
    else
        echo "No file containing 'latest' found. Continuing..."
        # Add your "continue" logic here (when no latest file is found)
        return 2 #No file found
    fi
}


download_genes=false
while getopts ":h:i:o:a:p:g:e:l:r:" opt; do
    case "${opt}" in
    i)
        taxon="${OPTARG}"
        ;;
    o)
        output_dir=$(realpath "${OPTARG}")"/"
        ;;
    a)
        api_key=$(cat "${OPTARG}")
        ;;
    l)
        limit_size="${OPTARG}"
        ;;
    p)
        prefix="${OPTARG}"
        ;;
    g)
        gene="${OPTARG}"
        download_genes=true
        ;;
    e)
        exclude="${OPTARG}"
        ;;
    r)
        reference="${OPTARG}"
        ;;
    h)
        print_help
        exit 0
        ;;
    \?)
        echo "Invalid option: -$OPTARG"
        print_help
        exit 1
        ;;
    esac
done

# START OF THE PROGRAM
echo "TSV: ""$taxon"
echo "Download: ""$output_dir"

: "${api_key:=$NCBI_API_KEY}"
if [[ -z ${api_key} ]]; then
    echo "NO API KEY FOUND: using 3 concurrent downloads"
fi
if [[ -z ${exclude} ]]; then
    exclude="$output_dir"exclusions.txt
fi

# Create temporary and output directories
mkdir -p "$output_dir" || {
    echo "Error creating output directories"
    exit 1
}

download_file="$output_dir""$taxon""_""$(date +'%d-%m-%Y')""_latest.tsv"
compare_name_and_rename 

if [ "$prefix" = "all" ]; then
    source_db="all"
elif [ "$prefix" = "GCA" ]; then
    source_db="GenBank"
elif [ "$prefix" = "GCF" ]; then
    source_db="RefSeq"
elif [ "$prefix" = "both" ]; then
    source_db="all"
else
    echo "Invalid prefix specified"
    exit 1
fi

if [ "$download_genes" = true ]; then
    "$utils_dir"datasets summary gene symbol "$gene" --taxon "$taxon" --as-json-lines ${api_key:+--api-key "$api_key"}
else
    if [ ! -f "$download_file" ]; then

        "$utils_dir"datasets summary genome taxon "$taxon" \
            --assembly-source "$source_db" \
            --assembly-version "latest" \
            --mag "exclude" \
            --as-json-lines \
            ${api_key:+ --api-key "$api_key"} \
            ${limit_size:+ --limit "$limit_size"} \
            ${reference:+ --reference} |
            "$utils_dir"dataformat tsv genome \
                --fields accession,organism-name,organism-infraspecific-strain,assmstats-total-sequence-len,assmstats-number-of-contigs,assmstats-contig-n50,assmstats-gc-count,assmstats-gc-percent >"$download_file"

    else
        echo "Summary for $taxon on $today already exists"
    fi
fi

if [ -f "$exclude" ]; then
    temp_file=$(mktemp "${download_file}.XXXXXX")
    awk -f "$utils_dir"filter.awk "$exclude" "$download_file" >"$temp_file"
    mv "$temp_file" "$download_file" || {
        echo "Failed to filter out accessions"
    }
    echo "Excluded accessions from $exclude"
fi

# Fun with flags on datasets v16+:
#      --annotated                 Limit to annotated genomes
#      --api-key string            Specify an NCBI API key
#      --as-json-lines             Output results in JSON Lines format
#      --assembly-level string     Limit to genomes at one or more assembly levels (comma-separated):
#                                    * chromosome
#                                    * complete
#                                    * contig
#                                    * scaffold
#                                     (default "[]")
#      --assembly-source string    Limit to 'RefSeq' (GCF_) or 'GenBank' (GCA_) genomes (default "all")
#      --assembly-version string   Limit to 'latest' assembly accession version or include 'all' (latest + previous versions)
#      --debug                     Emit debugging info
#      --exclude-atypical          Exclude atypical assemblies
#      --exclude-multi-isolate     Exclude assemblies from multi-isolate projects
#      --from-type                 Only return records with type material
#      --help                      Print detailed help about a datasets command
#      --limit string              Limit the number of genome summaries returned
#                                    * all:      returns all matching genome summaries
#                                    * a number: returns the specified number of matching genome summaries
#                                       (default "all")
#      --mag string                Limit to metagenome assembled genomes (only) or remove them from the results (exclude) (default "all")
#      --reference                 Limit to reference genomes
#      --released-after string     Limit to genomes released on or after a specified date (free format, ISO 8601 YYYY-MM-DD recommended)
#      --released-before string    Limit to genomes released on or before a specified date (free format, ISO 8601 YYYY-MM-DD recommended)
#      --report string             Choose the output type:
#                                    * genome:   Retrieve the primary genome report
#                                    * sequence: Retrieve the sequence report
#                                    * ids_only: Retrieve only the genome identifiers
#                                     (default "genome")
#      --search strings            Limit results to genomes with specified text in the searchable fields:
#                                  species and infraspecies, assembly name and submitter.
#                                  To search multiple strings, use the flag multiple times.
#      --version                   Print version of datasets

# Fun with flags on dataformat v16+:
#      --elide-header       Do not output header
#      --fields strings     Comma-separated list of fields
#      --force              Force dataformat to run without type check prompt
#  -h, --help               help for genome
#      --inputfile string   Input file (default "/dev/stdin")
#      --package string     Data package (zip archive), inputfile parameter is relative to the root path inside the archive

# --fields has stuff
#Mnemonic	Name
#accession	Assembly Accession
#ani-best-ani-match-ani	ANI Best ANI match ANI
#ani-best-ani-match-assembly	ANI Best ANI match Assembly
#ani-best-ani-match-assembly_coverage	ANI Best ANI match Assembly Coverage
#ani-best-ani-match-category	ANI Best ANI match Type Category
#ani-best-ani-match-organism	ANI Best ANI match Organism
#ani-best-ani-match-type_assembly_coverage	ANI Best ANI match Type Assembly Coverage
#ani-best-match-status	ANI Best match status
#ani-category	ANI Category
#ani-check-status	ANI Check status
#ani-comment	ANI Comment
#ani-submitted-ani-match-ani	ANI Declared ANI match ANI
#ani-submitted-ani-match-assembly	ANI Declared ANI match Assembly
#ani-submitted-ani-match-assembly_coverage	ANI Declared ANI match Assembly Coverage
#ani-submitted-ani-match-category	ANI Declared ANI match Type Category
#ani-submitted-ani-match-organism	ANI Declared ANI match Organism
#ani-submitted-ani-match-type_assembly_coverage	ANI Declared ANI match Type Assembly Coverage
#ani-submitted-organism	ANI Submitted organism
#ani-submitted-species	ANI Submitted species
#annotinfo-busco-complete	Annotation BUSCO Complete
#annotinfo-busco-duplicated	Annotation BUSCO Duplicated
#annotinfo-busco-fragmented	Annotation BUSCO Fragmented
#annotinfo-busco-lineage	Annotation BUSCO Lineage
#annotinfo-busco-missing	Annotation BUSCO Missing
#annotinfo-busco-singlecopy	Annotation BUSCO Single Copy
#annotinfo-busco-totalcount	Annotation BUSCO Total Count
#annotinfo-busco-ver	Annotation BUSCO Version
#annotinfo-featcount-gene-non-coding	Annotation Count Gene Non-coding
#annotinfo-featcount-gene-other	Annotation Count Gene Other
#annotinfo-featcount-gene-protein-coding	Annotation Count Gene Protein-coding
#annotinfo-featcount-gene-pseudogene	Annotation Count Gene Pseudogene
#annotinfo-featcount-gene-total	Annotation Count Gene Total
#annotinfo-method	Annotation Method
#annotinfo-name	Annotation Name
#annotinfo-pipeline	Annotation Pipeline
#annotinfo-provider	Annotation Provider
#annotinfo-release-date	Annotation Release Date
#annotinfo-release-version	Annotation Release Version
#annotinfo-report-url	Annotation Report URL
#annotinfo-software-version	Annotation Software Version
#annotinfo-status	Annotation Status
#assminfo-assembly-method	Assembly Assembly Method
#assminfo-atypicalis-atypical	Assembly Atypical Is Atypical
#assminfo-atypicalwarnings	Assembly Atypical Warnings
#assminfo-bioproject	Assembly BioProject Accession
#assminfo-bioproject-lineage-accession	Assembly BioProject Lineage Accession
#assminfo-bioproject-lineage-parent-accession	Assembly BioProject Lineage Parent Accession
#assminfo-bioproject-lineage-parent-accessions	Assembly BioProject Lineage Parent Accessions
#assminfo-bioproject-lineage-title	Assembly BioProject Lineage Title
#assminfo-biosample-accession	Assembly BioSample Accession
#assminfo-biosample-age	Assembly BioSample Age
#assminfo-biosample-attribute-name	Assembly BioSample Attribute Name
#assminfo-biosample-attribute-value	Assembly BioSample Attribute Value
#assminfo-biosample-biomaterial-provider-	Assembly BioSample Biomaterial provider
#assminfo-biosample-bioproject-accession	Assembly BioSample BioProject Accession
#assminfo-biosample-bioproject-parent-accession	Assembly BioSample BioProject Parent Accession
#assminfo-biosample-bioproject-parent-accessions	Assembly BioSample BioProject Parent Accessions
#assminfo-biosample-bioproject-title	Assembly BioSample BioProject Title
#assminfo-biosample-breed	Assembly BioSample Breed
#assminfo-biosample-collected-by	Assembly BioSample Collected by
#assminfo-biosample-collection-date	Assembly BioSample Collection date
#assminfo-biosample-cultivar	Assembly BioSample Cultivar
#assminfo-biosample-description-comment	Assembly BioSample Description Comment
#assminfo-biosample-description-organism-common-name	Assembly BioSample Description Organism Common Name
#assminfo-biosample-description-organism-infraspecific-breed	Assembly BioSample Description Organism Infraspecific Names Breed
#assminfo-biosample-description-organism-infraspecific-cultivar	Assembly BioSample Description Organism Infraspecific Names Cultivar
#assminfo-biosample-description-organism-infraspecific-ecotype	Assembly BioSample Description Organism Infraspecific Names Ecotype
#assminfo-biosample-description-organism-infraspecific-isolate	Assembly BioSample Description Organism Infraspecific Names Isolate
#assminfo-biosample-description-organism-infraspecific-sex	Assembly BioSample Description Organism Infraspecific Names Sex
#assminfo-biosample-description-organism-infraspecific-strain	Assembly BioSample Description Organism Infraspecific Names Strain
#assminfo-biosample-description-organism-name	Assembly BioSample Description Organism Name
#assminfo-biosample-description-organism-pangolin	Assembly BioSample Description Organism Pangolin Classification
#assminfo-biosample-description-organism-tax-id	Assembly BioSample Description Organism Taxonomic ID
#assminfo-biosample-description-title	Assembly BioSample Description Title
#assminfo-biosample-development-stage	Assembly BioSample Development stage
#assminfo-biosample-ecotype	Assembly BioSample Ecotype
#assminfo-biosample-geo-loc-name	Assembly BioSample Geographic location
#assminfo-biosample-host	Assembly BioSample Host
#assminfo-biosample-host-disease	Assembly BioSample Host disease
#assminfo-biosample-identified-by	Assembly BioSample Identified by
#assminfo-biosample-ids-db	Assembly BioSample Sample Identifiers Database
#assminfo-biosample-ids-label	Assembly BioSample Sample Identifiers Label
#assminfo-biosample-ids-value	Assembly BioSample Sample Identifiers Value
#assminfo-biosample-ifsac-category	Assembly BioSample IFSAC category
#assminfo-biosample-isolate	Assembly BioSample Isolate
#assminfo-biosample-isolate-name-alias	Assembly BioSample Isolate name alias
#assminfo-biosample-isolation-source	Assembly BioSample Isolation source
#assminfo-biosample-last-updated	Assembly BioSample Last updated
#assminfo-biosample-lat-lon	Assembly BioSample Latitude / Longitude
#assminfo-biosample-models	Assembly BioSample Models
#assminfo-biosample-owner-contact-lab	Assembly BioSample Owner Contact Lab
#assminfo-biosample-owner-name	Assembly BioSample Owner Name
#assminfo-biosample-package	Assembly BioSample Package
#assminfo-biosample-project-name	Assembly BioSample Project name
#assminfo-biosample-publication-date	Assembly BioSample Publication date
#assminfo-biosample-sample-name	Assembly BioSample Sample name
#assminfo-biosample-serotype	Assembly BioSample Serotype
#assminfo-biosample-serovar	Assembly BioSample Serovar
#assminfo-biosample-sex	Assembly BioSample Sex
#assminfo-biosample-source-type	Assembly BioSample Source type
#assminfo-biosample-status-status	Assembly BioSample Status Status
#assminfo-biosample-status-when	Assembly BioSample Status When
#assminfo-biosample-strain	Assembly BioSample Strain
#assminfo-biosample-sub-species	Assembly BioSample Sub-species
#assminfo-biosample-submission-date	Assembly BioSample Submission date
#assminfo-biosample-tissue	Assembly BioSample Tissue
#assminfo-blast-url	Assembly Blast URL
#assminfo-description	Assembly Description
#assminfo-level	Assembly Level
#assminfo-linked-assm-accession	Assembly Linked Assembly Accession
#assminfo-linked-assm-type	Assembly Linked Assembly Type
#assminfo-name	Assembly Name
#assminfo-notes	Assembly Notes
#assminfo-paired-assm-accession	Assembly Paired Assembly Accession
#assminfo-paired-assm-changed	Assembly Paired Assembly Changed
#assminfo-paired-assm-manual-diff	Assembly Paired Assembly Manual Diff
#assminfo-paired-assm-name	Assembly Paired Assembly Name
#assminfo-paired-assm-only-genbank	Assembly Paired Assembly Only Genbank
#assminfo-paired-assm-only-refseq	Assembly Paired Assembly Only RefSeq
#assminfo-paired-assm-status	Assembly Paired Assembly Status
#assminfo-refseq-category	Assembly Refseq Category
#assminfo-release-date	Assembly Release Date
#assminfo-sequencing-tech	Assembly Sequencing Tech
#assminfo-status	Assembly Status
#assminfo-submitter	Assembly Submitter
#assminfo-suppression-reason	Assembly Suppression Reason
#assminfo-synonym	Assembly Synonym
#assminfo-type	Assembly Type
#assmstats-contig-l50	Assembly Stats Contig L50
#assmstats-contig-n50	Assembly Stats Contig N50
#assmstats-gaps-between-scaffolds-count	Assembly Stats Gaps Between Scaffolds Count
#assmstats-gc-count	Assembly Stats GC Count
#assmstats-gc-percent	Assembly Stats GC Percent
#assmstats-genome-coverage	Assembly Stats Genome Coverage
#assmstats-number-of-component-sequences	Assembly Stats Number of Component Sequences
#assmstats-number-of-contigs	Assembly Stats Number of Contigs
#assmstats-number-of-organelles	Assembly Stats Number of Organelles
#assmstats-number-of-scaffolds	Assembly Stats Number of Scaffolds
#assmstats-scaffold-l50	Assembly Stats Scaffold L50
#assmstats-scaffold-n50	Assembly Stats Scaffold N50
#assmstats-total-number-of-chromosomes	Assembly Stats Total Number of Chromosomes
#assmstats-total-sequence-len	Assembly Stats Total Sequence Length
#assmstats-total-ungapped-len	Assembly Stats Total Ungapped Length
#checkm-completeness	CheckM completeness
#checkm-completeness-percentile	CheckM completeness percentile
#checkm-contamination	CheckM contamination
#checkm-marker-set	CheckM marker set
#checkm-marker-set-rank	CheckM marker set rank
#checkm-species-tax-id	CheckM species tax id
#checkm-version	CheckM version
#current-accession	Current Accession
#organelle-assembly-name	Organelle Assembly Name
#organelle-bioproject-accessions	Organelle BioProject Accessions
#organelle-description	Organelle Description
#organelle-infraspecific-name	Organelle Infraspecific Name
#organelle-submitter	Organelle Submitter
#organelle-total-seq-length	Organelle Total Seq Length
#organism-common-name	Organism Common Name
#organism-infraspecific-breed	Organism Infraspecific Names Breed
#organism-infraspecific-cultivar	Organism Infraspecific Names Cultivar
#organism-infraspecific-ecotype	Organism Infraspecific Names Ecotype
#organism-infraspecific-isolate	Organism Infraspecific Names Isolate
#organism-infraspecific-sex	Organism Infraspecific Names Sex
#organism-infraspecific-strain	Organism Infraspecific Names Strain
#organism-name	Organism Name
#organism-pangolin	Organism Pangolin Classification
#organism-tax-id	Organism Taxonomic ID
#source_database	Source Database
#type_material-display_text	Type Material Display Text
#type_material-label	Type Material Label
#wgs-contigs-url	WGS contigs URL
#wgs-project-accession	WGS project accession
#wgs-url	WGS URL
