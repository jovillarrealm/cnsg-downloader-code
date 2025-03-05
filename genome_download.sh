#!/bin/bash

date_format='%d-%m-%Y'
prefix="both"
output_dir="./"
batch_size=50000

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

print_help() {
    local script_name=$(basename "$0")

    echo ""
    echo "Usage: $script_name [OPTIONS] -i TAXON"
    echo ""
    echo "Description:"
    echo "  This script downloads genomic data from NCBI based on a taxon name or ID."
    echo "  It handles deduplication, file format conversions, optional annotation, and more."
    echo "  Requires 'unzip', 'summary_download', 'tsv_downloader.sh', and 'clis_download.sh' to be present."
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
    echo "      Path to a file containing your NCBI API key. If not provided, it attempts to use the NCBI_API_KEY environment variable."
    echo "      You can obtain an API key from your NCBI account."
    echo ""
    echo "  -p, PREFIX"
    echo "      Preferred prefix for deduplication: GCF (RefSeq), GCA (GenBank), all (no deduplication),"
    echo "      or both (prefers RefSeq). (Default: '$prefix')"
    echo "      Options: GCF, GCA, all, both"
    echo ""
    echo "  -e, EXCLUSIONS_FILE"
    echo "      Path to an exclusions file. (Default: \"$output_dir\"exclusions.txt)"
    echo ""
    echo "  -b, BATCH_SIZE"
    echo "      Number of files in each GENOMIC folder. (Default: $batch_size)"
    echo ""
    echo "  -r, true"
    echo "      Downloads only reference genomes. The argument value is ignored but must be present."
    echo ""
    echo "  -l, NUMBER"
    echo "      Limits the summary to the first NUMBER of genomes."
    echo ""
    echo "  --keep-zip-files=true"
    echo "      Keeps downloaded genomes as zip files instead of decompressing them."
    echo "      Renames the inner fna file without recompression."
    echo ""
    echo "  --convert-gzip-files=true"
    echo "      Keeps downloaded genomes as gzip files instead of recompressing them."
    echo ""
    echo "  --annotate=true"
    echo "      Adds GFF annotations to a separate directory."
    echo ""
    echo "  -h, "
    echo "      Displays this help message and exits."
    echo ""
    echo "Example Usage:"
    echo "  $script_name -i Aphelenchoides -o ./Aphelenchoides -a ./ncbi_api_key.txt -p all"
    echo "  $script_name -i 90723 -o ./Aphelenchoides -a ncbi_api_key.txt -p 'both'"
    echo ""
    echo "Dependencies:"
    echo "  unzip, summary_download, tsv_downloader.sh, clis_download.sh"
    echo ""
    echo "Date Format: $date_format"
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

# Make a directory filled with hardlinks to
make_hardlinks() {

    mkdir -p "$refseq_dir"
    find "$dir" -name "$glob_pattern" -exec ln -f {} "$refseq_dir" \;
    # Check if the directory exists
    if [[ -d "$refseq_dir" ]]; then
        # Check if the directory is empty
        if [[ -z $(ls -A "$refseq_dir") ]]; then
            rm -r "$refseq_dir"
        fi
    else
        echo "**** ERROR: no RefSeq directory was created"
    fi
}

process_directory() {
    if [[ ! -f "$stats_file" ]]; then
        count-fasta-rs -c "$stats_file" -d "$dir"
    else
        echo "Stats file $stats_file already exists"
    fi

    dircount=$((dircount + 1))

    plots_dir="$utils_dir"plots/
    uv run --project "$plots_dir" "$plots_dir"plots-count-fasta.py "$stats_file"

}


scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
utils_dir="$scripts_dir"utils/
annotate=
while getopts ":h:i:o:a:p:e:b:l:r:" opt; do
    case "${opt}" in
    i)
        taxon="${OPTARG}"
        # Logic to guard against weird querys to datasets
        if [ -z ${taxon+x} ]; then
            echo "Please specify a taxon to download"
            print_help
            exit 1
        elif [ "$taxon" = "-a" ]; then
            echo "Please specify a taxon to download"
            print_help
            exit 1
        elif [ "$taxon" = "-o" ]; then
            echo "Please specify a taxon to download"
            print_help
            exit 1
        elif [ "$taxon" = "-p" ]; then
            echo "Please specify a taxon to download"
            print_help
            exit 1
        fi
        ;;
    o)
        mkdir -p "$OPTARG"

        output_dir=$(realpath "${OPTARG}")"/"
        ;;
    a)
        api_key_file="${OPTARG}"
        api_key=$(cat "${OPTARG}")
        ;;
    e)
        exclusions="${OPTARG}"
        ;;
    p)
        prefix="${OPTARG}"
        ;;
    b)
        batch_size="${OPTARG}"
        ;;
    r)
        reference="${OPTARG}"
        ;;
    l)
        limit_size="${OPTARG}"
        ;;
    h)
        print_help
        exit 0
        ;;
    *)
        shift $((OPTIND - 1))

        # Handle long flag outside getopts
        for arg in "$@"; do
            case $arg in
            --keep-zip-files=*)
                long_flag_value="${arg#*=}"

                keep_zip_flag="${long_flag_value:+--keep-zip-files=true}"
                ;;
            --convert-gzip-files=*)
                long_flag_value="${arg#*=}"

                convert_gzip_flag="${long_flag_value:+--convert-gzip-files=true}"
                ;;
            --annotate=*)
                long_flag_value="${arg#*=}"
                annotate=true
                ;;
            *)
                echo "Invalid option: -$OPTARG"
                print_help
                exit 1
                ;;
            esac
        done
        ;;
    esac
done

# Shift processed options
check_api_key

# When is this running, for traceability
today="$(date +$date_format)"

"$utils_dir"clis_download.sh

echo
echo
echo "** STARTING SUMMARY DOWNLOAD **"
start_time=$(date +%s)
# If the summary already ran before, skip it
download_file="$output_dir""$taxon""_""$today""_latest.tsv"

# shellcheck disable=SC2086
if ! "$scripts_dir"summary_download.sh \
    -i "$taxon" \
    -o "$output_dir" \
    -p "$prefix" \
    ${api_key_file:+-a \"$api_key_file\"} \
    ${limit_size:+-l "$limit_size"} \
    ${exclusions:+ -e "$exclusions"} \
    ${reference:+-r true}; then
    exit 1
fi

echo "** DONE **"
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
echo "Took $elapsed_time seconds"
echo

# This check if each file in the summary is already downloaded is if its not already not there
echo
echo
echo "** STARTING DOWNLOADS **"
start_time=$(date +%s)
# shellcheck disable=SC2086
if ! "${scripts_dir}tsv_datasets_downloader.sh" -i "$download_file" \
    -o "$output_dir" -p "$prefix" -b "$batch_size" \
    ${api_key_file:+-a \"$api_key_file\"} \
    $keep_zip_flag \
    $convert_gzip_flag \
    ${annotate:+--annotate=true}; then
    exit 1
fi
rm -fr "$output_dir""tmp/"
echo
echo "** DONE **"
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
echo "Took $elapsed_time seconds"
echo

echo
echo "** STARTING SEGREGATION AND SECUENCE ANALYSIS **"
start_time=$(date +%s)
# Process main genomic directories
dircount=1
find "$output_dir" -maxdepth 1 -name "GENOMIC[0-9]*" -type d -print0 | while IFS= read -r -d '' dir; do
    stats_file="$output_dir""$taxon""_""$today""_stats$dircount.csv"
    process_directory
done

# Make hardlinks
if [[ "$prefix" == "GCF" || "$prefix" == "GCA" ]]; then
    true
else
    dircount=1
    find "$output_dir" -maxdepth 1 -name "GENOMIC[0-9]*" -type d -print0 | while IFS= read -r -d '' dir; do
        # shellcheck disable=SC2140
        refseq_dir="$output_dir"RefSeq/"GENOMIC$dircount/"
        glob_pattern="GCF_*"
        make_hardlinks
        glob_pattern="GCA_*"
        # shellcheck disable=SC2140
        refseq_dir="$output_dir"GenBank/"GENOMIC$dircount/"
        make_hardlinks
        dircount=$((dircount + 1))
    done

    # Process RefSeq directories
    dircount=1
    stats_file="$output_dir"RefSeq/"$taxon""_""$today""_stats$dircount.csv"
    if [[ -f "$stats_file" ]]; then
        echo "RefSeq Stats file already exists"
    else
        find "$output_dir"RefSeq/ -maxdepth 1 -name "GENOMIC[0-9]*" -type d -print0 | while IFS= read -r -d '' dir; do
            stats_file="$output_dir"RefSeq/"$taxon""_""$today""_RefSeq_stats$dircount.csv"
            process_directory
        done
    fi
    if [ -z "$(ls -A "$output_dir"RefSeq/)" ]; then
        rm -d "$output_dir"RefSeq/
    fi

    # Process GenBank directories
    dircount=1
    stats_file="$output_dir"GenBank/"$taxon""_""$today""_stats$dircount.csv"
    if [[ -f "$stats_file" ]]; then
        echo "GenBank Stats file already exists"
    else
        find "$output_dir"GenBank/ -maxdepth 1 -name "GENOMIC[0-9]*" -type d -print0 | while IFS= read -r -d '' dir; do
            stats_file="$output_dir"GenBank/"$taxon""_""$today""_GenBank_stats$dircount.csv"
            process_directory
        done
    fi
    if [ -z "$(ls -A "$output_dir"GenBank/)" ]; then
        rm -d "$output_dir"GenBank/
    fi
fi

echo "** DONE **"
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
echo "Took $elapsed_time seconds"
echo
echo
