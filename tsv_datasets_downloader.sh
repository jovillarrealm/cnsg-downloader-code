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
output_dir=./
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
utils_dir="$scripts_dir"utils/

print_help() {
    echo ""
    echo "Usage: $0 -i tsv/input/file/path [-o path/for/dir/GENOMIC] [-a path/to/api/key/file] [-p preferred prefix] [--keep-zip-files=true] [--annotate=true]"
    echo ""
    echo ""
    echo "Arguments:"
    echo "-i            path to tsv file with datasets summary output"
    echo "-o            rel path to folder where GENOMIC*/ folders will be created [Default: $output_dir]"
    echo "-a            path to file containing an NCBI API key. If you have a ncbi account, you can generate one."
    echo "-p            tsv_downloader performs deduplication of redundant genomes between GenBank and RefSeq [Default: '$prefix']"
    echo "              [Options: 'GCF 'GCA' 'all' 'both']"
    echo "-b            batch size of each GENOMIC folder because even 'ls' starts to fail with directories with too many files [Default: 50_000]"
    echo ""
    echo "'GCA' (GenBank), 'GCF' (RefSeq), 'all' (contains duplication), 'both' (prefers RefSeq genomes over GenBank)"
    echo ""
    echo "--keep-zip-files=true  ensures downloaded genomes are not decompressed after download, also it renames the inner fna file (without recompressing it)"
    echo ""
    echo "--convert-gzip-files  ensures downloaded genomes are not recompressed after download into a gz file"
    echo ""
    echo "--annotate=true   adds gff annotations"
    echo ""
    echo "This script assumes 'datasets' and 'dataformat' are in PATH"
    echo "It depends on mv, unzip, awk, xargs, datasets, dataformat, zipnote"
    echo ""
    echo ""
    echo ""
}

if [[ $# -lt 2 ]]; then
    print_help
    exit 1
fi

num_process=3
keep_zip_files=false
convert_gzip_files=false
annotate=
while getopts ":h:p:i:o:a:b:" opt; do
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
                long_flag_value="${arg#*=}"
                keep_zip_files=true
                ;;
            --annotate=*)
                long_flag_value="${arg#*=}"
                annotate=true
                ;;
            --convert-gzip-files=*)
                long_flag_value="${arg#*=}"

                convert_gzip_files=true
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
# shellcheck source=utils/awk_programs.sh
eval "$(cat "$utils_dir"awk_programs.sh)"

# shellcheck source=utils/tsv_downloader.sh
eval "$(cat "$utils_dir"tsv_downloader.sh)"

# shellcheck source=utils/download_unzip.sh
eval "$(cat "$utils_dir"download_unzip.sh)"

setup_data

delete_exclusions
# can_we_use_wait_n is set
# tmp_names is set
# genomic_dir is set

while read -r accession accession_name filename; do
    # Check if we have reached the batch size
    if ((file_count % batch_size == 0)); then
        # Increment batch number and update the genomic directory
        batch_number=$((batch_number + 1))
        update_dir_count
    fi
    # Start download in the background
    download_and_unzip &

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
