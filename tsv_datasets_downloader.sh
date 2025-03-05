#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

batch_size=50001
prefix="both"
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
    : "${api_key:=$NCBI_API_KEY}"
    if [[ -z ${api_key+x} ]]; then
        num_process=3
    else
        num_process=10
    fi
}


print_help() {
    local script_name=$(basename "$0")

    echo ""
    echo "Usage: $script_name [OPTIONS] -i INPUT_FILE"
    echo ""
    echo "Description:"
    echo "  This script downloads genomic data from NCBI based on a summary TSV file."
    echo "  It handles deduplication, file format conversions, and optional annotation."
    echo "  Requires 'datasets' and 'dataformat' to be in your PATH."
    echo ""
    echo "Required Arguments:"
    echo "  -i, INPUT_FILE"
    echo "      Path to the TSV file containing dataset summaries."
    echo ""
    echo "Optional Arguments:"
    echo "  -o, OUTPUT_DIR"
    echo "      Path to the directory where GENOMIC*/ folders will be created."
    echo "      (Default: directory of the input file)"
    echo ""
    echo "  -a, API_KEY_FILE"
    echo "      Path to a file containing your NCBI API key. If provided, increases processing speed."
    echo "      You can obtain an API key from your NCBI account."
    echo ""
    echo "  -p, PREFIX"
    echo "      Preferred prefix for deduplication: GCF (RefSeq), GCA (GenBank), all (no deduplication),"
    echo "      or both (prefers RefSeq). (Default: '$prefix')"
    echo "      Options: GCF, GCA, all, both"
    echo ""
    echo "  -b, BATCH_SIZE"
    echo "      Batch size for each GENOMIC folder to avoid issues with large directories. (Default: $batch_size)"
    echo ""
    echo "  --keep-zip-files=true"
    echo "      Keeps downloaded genomes as zip files instead of decompressing them."
    echo "      Renames the inner fna file without recompression."
    echo ""
    echo "  --convert-gzip-files=true"
    echo "      Keeps downloaded genomes as gzip files instead of recompressing them."
    echo ""
    echo "  --annotate=true"
    echo "      Adds GFF annotations to the downloaded genomes."
    echo ""
    echo "  -h"
    echo "      Displays this help message and exits."
    echo ""
    echo "Dependencies:"
    echo "  mv, unzip, awk, xargs, datasets, dataformat, zipnote"
    echo ""

    check_api_key # run the function to display api key info.
    echo ""
    echo "NCBI API Key Information:"
    if [[ -z ${api_key+x} ]]; then
        if [ -z "$NCBI_API_KEY" ]; then
            echo "  WARNING: NCBI API key cannot be acquired from this environment."
            echo "  Please set the NCBI_API_KEY environment variable or use the -a option."
            echo "  Using default lower process number."
        else
            echo "  INFO: An NCBI API key can be acquired from the NCBI_API_KEY environment variable."
            echo "  Using higher process number."
        fi
    else
        echo "  INFO: NCBI API key provided via -a option. Using higher process number."
    fi
    echo ""
}

if [[ $# -lt 2 ]]; then
    print_help
    exit 1
fi


#More variables
mode="fasta"
annotate=
batch_number=0
file_count=0


# Function to check if we can use wait -n on the current system based on the bash version. output written to can_use_wait_n
can_we_use_wait_n() {
    # Extract major and minor version numbers
    IFS='.' read -r major minor _patch <<<"$BASH_VERSION"
    # Compare the major and minor versions to check if they meet the minimum requirement
    if [[ "$major" -gt 4 ]] || { [[ "$major" -eq 4 ]] && [[ "$minor" -ge 3 ]]; }; then
        echo "Bash version $BASH_VERSION meets the minimum required version (4.3)."
        can_use_wait_n="true"
    else
        echo "Bash version $BASH_VERSION is too old. Minimum required version is 4.3."
        can_use_wait_n="false"
    fi
}
# Create tmp dir
setup_data() {
    : "${output_dir:=$(dirname "$input_file")/}"
    echo "TSV: " "$input_file"
    echo "Output directory for GENOMIC: " "$output_dir"
    echo "Preferred prefix: $prefix"
    tmp_dir="$output_dir""tmp/"
    tmp_names="$tmp_dir""/tmp_names"
    mkdir -p "$tmp_dir"
    if [[ -z ${exclude} ]]; then
        exclude="$output_dir"exclusions.txt
    fi
    can_we_use_wait_n
    check_api_key
}

update_dir_count() {
    genomic_dir="${output_dir}GENOMIC${batch_number}/"
    mkdir -p "$genomic_dir" 
    if [[ $annotate = "true" ]]; then
        gff_dir="${output_dir}GFF${batch_number}/"
        mkdir -p "$gff_dir"
    fi
    echo "Created/Using directory: $genomic_dir"
}

while getopts ":h:p:i:o:a:b:e:" opt; do
    case "${opt}" in
    i)
        input_file="${OPTARG}"
        ;;
    o)
        output_dir=$(realpath "${OPTARG}")"/"
        ;;
    a)
        api_key=$(cat "${OPTARG}")
        num_process=10
        ;;
    p)
        prefix="${OPTARG}"
        ;;
    b)
        batch_size="${OPTARG}"
        ;;
    e)
        exclude="${OPTARG}"
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
                _long_flag_value="${arg#*=}"
                mode="zip"
                ;;
            --annotate=*)
                _long_flag_value="${arg#*=}"
                annotate=true
                ;;
            --convert-gzip-files=*)
                _long_flag_value="${arg#*=}"

                mode="gzip"
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



# START OF SCRIPT
setup_data
"$utils_dir"exclude.sh "$output_dir" "$exclude" "$prefix" 
"$utils_dir"awk_programs.sh "$input_file" "$tmp_names" "$prefix"


while read -r accession accession_name filename; do
    # Check if we have reached the batch size
    if ((file_count % batch_size == 0)); then
        # Increment batch number and update the genomic directory
        batch_number=$((batch_number + 1))
        update_dir_count
    fi

    # Start download in the background
    "$utils_dir"download_unzip.sh "$accession" "$accession_name" "$filename" \
    "$tmp_dir" "$genomic_dir" "$output_dir" "$gff_dir" "$mode" &

    # Update the file counter
    file_count=$((file_count + 1))

    # Limit the number of concurrent jobs
    if [[ $(jobs -r -p | wc -l) -ge $num_process ]]; then
        if [[ $can_use_wait_n = "true" ]]; then
            # Wait until a new job can be created
            wait -n
        else
            # Wait until batch of downloads has finished (for bash <4.2)
            wait
        fi
    fi

done <"$tmp_names"

wait
