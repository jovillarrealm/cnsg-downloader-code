#!/bin/bash

date_format='%d-%m-%Y'
prefix="both"
output_dir="./"

check_api_key() {
    if [[ -z ${api_key+x} ]]; then
        if [ -z "$NCBI_API_KEY" ]; then
            echo "WARNING: NCBI API KEY COULD NOT BE AQUIRED FROM ENV"
            echo "PLEASE GET ONE FOR FASTER AND BETTER TRANSFERS"
        else
            api_key=$NCBI_API_KEY
            echo "INFO: An NCBI API key can be aquired from this environment"
        fi
    fi
}

print_help() {
    echo ""
    echo "Usage: $0 -i <taxon> [-o <directory_output>] [-a path/to/api/key/file] [-p prefered prefix]"
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
    echo ""
    check_api_key
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
    refseq_dir="$output_dir""GENOMIC_RefSeq/"
    mkdir -p "$refseq_dir"
    find "$genomic_dir" -name "GCF_*" -exec ln -fi {} "$refseq_dir" \;
    # Check if the directory exists
    if [[ -d "$refseq_dir" ]]; then
        # Check if the directory is empty
        if [[ -z $(ls -A "$refseq_dir") ]]; then
            echo "No RefSeq Sequences found."
            rm -r "$refseq_dir"
        fi
    else
        echo "**** ERROR: no RefSeq directory was created"
    fi
}

os=$(uname)
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
batch_size=50000
while getopts ":h:i:o:a:p:b:" opt; do
    case "${opt}" in
    i)
        taxon="${OPTARG}"
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
        if [ "$os" = "Darwin" ]; then
            mkdir -p "$OPTARG"
        fi
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

check_api_key

# When is this running, for traceability
today="$(date +$date_format)"

"$scripts_dir"clis_download.sh

echo
echo
echo "** STARTING SUMMARY DOWNLOAD **"
start_time=$(date +%s)
# If the summary already ran before, skip it
download_file="$output_dir""$taxon""_""$today"".tsv"
if [ ! -f "$download_file" ]; then
    if [ -z ${api_key_file+x} ]; then
        if [ -z ${api_key+x} ]; then
            echo "WARNING: API KEY NOT SET, PLEASE GET ONE FOR FASTER AND BETTER TRANSFERS"
        fi
        if ! "$scripts_dir"summary_download.sh -i "$taxon" -o "$output_dir" -p "$prefix"; then
            exit 1
        fi

    else
        if ! "$scripts_dir"summary_download.sh -i "$taxon" -o "$output_dir" -p "$prefix" -a "$api_key_file"; then
            exit 1
        fi
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
if [ -z ${api_key_file+x} ]; then
    if [ -z ${api_key+x} ]; then
        echo "API KEY NOT SET, PLEASE GET ONE FOR FASTER AND BETTER TRANSFERS"
    fi
    if ! "$scripts_dir"tsv_datasets_downloader.sh -i "$download_file" -o "$output_dir" -p "$prefix" -b "$batch_size"; then
        exit 1
    fi
else
    if ! "$scripts_dir"tsv_datasets_downloader.sh -i "$download_file" -o "$output_dir" -p "$prefix" -b "$batch_size" -a "$api_key_file"; then
        exit 1
    fi
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
# Make hardlinks
genomic_dir="$output_dir""GENOMIC1/"
make_hardlinks

dircount=1

# Stats if they don´t already exist
while IFS= read -r -d '' dir; do
    stats_file="$output_dir""$taxon""_""$today""_stats$dircount.csv"
    # Make the file if it does not already exist
    if [ ! -f "$stats_file" ]; then
        count-fasta-rs -c "$stats_file" -d "$dir"
    else
        echo "Stats file $stats_file already exists"
    fi
    dircount=$((dircount + 1))
    if [ "$os" = "Darwin" ]; then
        count-fasta-plots "$stats_file"
    fi
done < <(find "$output_dir" -name "GENOMIC*" -type d -print0)

if [[ -d "$refseq_dir" ]]; then
    dircount=1
    stats_file="$refseq_dir""$taxon""_""$today""_RefSeq_stats$dircount.csv"
    if [ ! -f "$stats_file" ]; then
        echo "Analyzing Refseq sequences"
        while IFS= read -r -d '' dir; do
            stats_file="$refseq_dir""$taxon""_""$today""_RefSeq_stats$dircount.csv"
            if [ ! -f "$stats_file" ]; then
                count-fasta-rs -c "$stats_file" -d "$dir"
            else
                echo "Stats file $stats_file already exists"
            fi
            dircount=$((dircount + 1))
            if [ "$os" = "Darwin" ]; then
                count-fasta-plots "$stats_file"
            fi
        done < <(find "$output_dir" -name "GENOMIC_RefSeq*" -type d -print0)
    else
        echo "RefSeq Stats file already exists"
    fi
fi
echo "** DONE **"
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
echo "Took $elapsed_time seconds"
echo
echo
