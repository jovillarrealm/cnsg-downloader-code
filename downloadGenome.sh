#!/bin/bash

print_help() {
    echo ""
    echo "Usage: $0 -i <taxon> [-o <directory_output>] [-a path/to/api/key/file] [-p prefered prefix]"
    echo ""
    echo "Arguments:"
    echo "-i <taxon>    Can be a name or NCBI Taxonomy ID"
    echo "-o            rel path to folder where GENOMIC*/ folders will be created [Default: ./]"
    echo "-a            path to file containing an NCBI API key. If you have a ncbi account, you can generate one."
    echo "-p            tsv_downloader performs deduplication of redundant genomes between GenBank and RefSeq [Default: 'GCF']"
    echo "              [Options: 'GCF 'GCA' 'all']"
    echo ""
    echo ""
    echo "You should have an API key if possible"
    echo ""
    echo "Example usage:"
    echo "cnsg-downloader-code/downloadGenome.sh -i Aphelenchoides -o ./Aphelenchoides -a ncbi_api_key.txt -p all"
    echo ""
    echo "This script assumes unzip is installed and next to"
    echo "summary_downloader and tsv_downloader.sh and clis_download.sh"
    echo ""
    echo "date format is '%d-%m-%Y'"
    echo ""
    echo ""
}

if [[ $# -lt 2 ]]; then
    print_help
    exit 1
fi


# Make a directory filled with hardlinks to
make_hardlinks() {
    ref_seq_dir="$output_dir""GENOMIC_ref_seq/"
    mkdir -p "$ref_seq_dir"
    find "$genomic_dir" -name "GCF_*" -exec ln -fi {} "$ref_seq_dir" \;
    # Check if the directory exists
    if [[ -d "$ref_seq_dir" ]]; then
        # Check if the directory is empty
        if [[ -z $(ls -A "$ref_seq_dir") ]]; then
            echo "Directory is empty. No RefSeq Secuences found."
            rm -r "$ref_seq_dir"
        fi
    else
        echo "**** ERROR: no RefSeq directory was created"
    fi
}


scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
output_dir="./"
prefix="GCF"
while getopts ":h:i:o:a:p:" opt; do
    case "${opt}" in
        i)
            taxon="${OPTARG}"
        ;;
        o)
            output_dir=$(realpath "${OPTARG}")"/"
        ;;
        a)
            api_key_file="${OPTARG}"
        ;;
        p)
            prefix="${OPTARG}"
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

if [ -z "${taxon}" ]; then
    echo "Please specify a taxon to download"
    print_help
    exit 1
fi

# When is this running, for traceability
today="$(date +'%d-%m-%Y')"

"$scripts_dir"clis_download.sh

echo
echo
echo "** STARTING SUMMARY DOWNLOAD **"
start_time=$(date +%s)
# If the summary already ran before, skip it
download_file="$output_dir""$taxon""_""$today"".tsv"
if [ ! -f "$download_file" ];then
    if [ -z ${api_key_file+x} ]; then
        "$scripts_dir"summary_downloader.sh -i "$taxon" -o "$output_dir"
        echo "API KEY FILE NOT SET, PLEASE GET ONE FOR FASTER AND BETTER TRANSFERS"
    else
        "$scripts_dir"summary_downloader.sh -i "$taxon" -o "$output_dir" -a "$api_key_file"
    fi
    
else
    echo "Summary for $today exists"
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
    echo "API KEY FILE NOT SET, PLEASE GET ONE FOR FASTER AND BETTER TRANSFERS"
    "$scripts_dir"tsv_datasets_downloader.sh -i "$download_file" -o "$output_dir" -p "$prefix"
else
    "$scripts_dir"tsv_datasets_downloader.sh -i "$download_file" -o "$output_dir" -a "$api_key_file" -p "$prefix"
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
genomic_dir="$output_dir""GENOMIC/"
make_hardlinks
echo "Hardlinks made"


# Stats if they don´t already exist
dircount=0
num_process="$(nproc)"
num_process="$((num_process / 2))"

# Make the file if it does not already exist

while IFS= read -r -d '' dir
do
    stats_file="$output_dir""$taxon""_""$today""_stats$dircount.csv"
    if [ ! -f "$stats_file" ];then
        count-fasta-rs -c "$stats_file" -d "$dir"
        dircount=$((dircount + 1))
    else
        echo "Stats file $stats_file already exists"
    fi
done <   <(find "$output_dir" -name "GENOMIC*" -type d -print0)




if [[ -d "$ref_seq_dir" ]]; then
    dircount=0
    stats_refseq_file="$ref_seq_dir""$taxon""_""$today""_refseq_stats$dircount.csv"
    if [ ! -f "$stats_refseq_file" ];then
        echo "Analyzing Refseq secuences"
        while IFS= read -r -d '' dir
        do
            stats_refseq_file="$ref_seq_dir""$taxon""_""$today""_refseq_stats$dircount.csv"
            if [ ! -f "$stats_refseq_file" ];then
                count-fasta-rs -c "$stats_refseq_file" -d "$dir"
                dircount=$((dircount + 1))
            else
                echo "Stats file $stats_refseq_file already exists"
            fi
        done <   <(find "$output_dir" -name "GENOMIC*" -type d -print0)
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


