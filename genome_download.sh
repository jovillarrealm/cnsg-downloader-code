#!/bin/bash

date_format='%d-%m-%Y'
prefix="both"
output_dir="./"

check_api_key() {
    if [[ -z ${api_key+x} ]]; then
        if [ -z "$NCBI_API_KEY" ]; then
            echo "INFO: NCBI API key cannot be aquired from this environment"
        else
            api_key=$NCBI_API_KEY
            echo "INFO: An NCBI API key can be aquired from this environment"
        fi
    fi
}

print_help() {
    echo ""
    echo "Usage: $0 -i <taxon> [-o <directory_output>] [-a path/to/api/key/file] [-p prefered prefix] [--keep-zip-files=true] [--convert-gzip-files=true] [--annotate=true]"
    echo ""
    echo ""
    echo "Arguments:"
    echo "-i <taxon>    Can be a name or NCBI Taxonomy ID"
    echo "-o            rel path to folder where GENOMIC*/ folders will be created [Default: $output_dir]"
    echo "-p            tsv_downloader performs deduplication of redundant genomes between GenBank and RefSeq [Default: '$prefix']"
    echo "              [Options: 'GCF 'GCA' 'all' 'both']"
    echo ""
    echo "'GCA' (GenBank), 'GCF' (RefSeq), 'all' (contains duplication), 'both' (prefers RefSeq genomes over GenBank)"
    echo ""
    echo "-a            path to file containing an NCBI API key. If you have a ncbi account, you can generate one. If it's not passed, this script tries to get it from env."
    echo "-r            specify with any string to download only reference genomes"
    echo "-l <Number>   limit the summary to the first <Number> of genomes"
    echo ""
    check_api_key
    echo ""
    echo "--keep-zip-files=true  ensures downloaded genomes are not decompressed after download, also it renames the inner fna file (without recompressing it)"
    echo ""
    echo "--convert-gzip-files  ensures downloaded genomes are not recompressed after download into a gz file"
    echo ""
    echo "--annotate=true   adds gff annotations"
    echo ""
    echo ""
    echo "Example usage:"
    echo "cnsg-downloader-code/downloadGenome.sh -i Aphelenchoides -o ./Aphelenchoides -a ./ncbi_api_key.txt -p all"
    echo "cnsg-downloader-code/downloadGenome.sh -i 90723 -o ./Aphelenchoides -a ncbi_api_key.txt -p 'both'"
    echo ""
    echo "This script assumes unzip is installed and next to"
    echo "summary_download and tsv_downloader.sh and clis_download.sh"
    echo ""
    echo "date format is $date_format"
    echo ""
    echo ""
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

    if [[ "$os" == "Darwin" ]]; then
        count-fasta-plots "$stats_file"
    fi
}

os=$(uname)
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
batch_size=50000
annotate=
while getopts ":h:i:o:a:p:b:l:r:" opt; do
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
        limit_flag="${limit_size:+-l "$limit_size"}"
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

"$scripts_dir"clis_download.sh

echo
echo
echo "** STARTING SUMMARY DOWNLOAD **"
start_time=$(date +%s)
# If the summary already ran before, skip it
api_key_flag="${api_key_file:+-a \"$api_key_file\"}"
download_file="$output_dir""$taxon""_""$today"".tsv"
if [ ! -f "$download_file" ]; then
    # shellcheck disable=SC2086
    if ! "$scripts_dir"summary_download.sh \
        -i "$taxon" \
        -o "$output_dir" \
        -p "$prefix" \
        $api_key_flag \
        $limit_flag \
        ${reference:+-r true}; then
        exit 1
    fi
else
    echo "Summary for $taxon on $today already exists"
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
    $api_key_flag $keep_zip_flag $convert_gzip_flag \
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
