#!/bin/bash

batch_size=50000
prefix="both"
output_dir=./
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/

print_help() {
    echo ""
    echo "Usage: $0 -i tsv/input/file/path [-o path/for/dir/GENOMIC] [-a path/to/api/key/file] [-p preferred prefix] [--keep-zip-files=true]"
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

process_filename() {
    awk 'BEGIN { FS="\t"; OFS="\t" } {
    # Remove version number of Assembly Accession, or $1
    split($1, arr, ".")
    var1 = arr[1]
    # Remove GCA_ GCF_
    split(var1, nodb, "_")
    var4 = nodb[2]
    # Take only first 2 words in Organism Name y eso equivale a genero y especie? and replace spaces with '-'
    gsub(/[^a-zA-Z0-9 ]/, "", $2)
    split($2, words, " ")
    var2 = words[1] "-" words[2]
    # Remove non-alphanumeric characters from $3 and replace spaces with '-'
    gsub(/ /, "-", $3)
    gsub(/[^a-zA-Z0-9\-]/, "", $3)
    # Remove consecutive "-" in $3
    gsub(/-+/, "-", $3)
    var3 = $3
    # Output to the following variables: accession accession_name filename
    print $1,var1, var1"_"var2"_"var3, var4
    }'
}

process_filename_redundant() {
    awk 'BEGIN { FS="\t"; OFS="\t" } {
    # Remove version number of Assembly Accession, or $1
    split($1, arr, ".")
    var1 = arr[1]
    # Remove GCA_ GCF_
    split(var1, nodb, "_")
    var4 = nodb[2]
    # Take only first 2 words in Organism Name y eso equivale a genero y especie? and replace spaces with '-'
    gsub(/[^a-zA-Z0-9 ]/, "", $2)
    split($2, words, " ")
    var2 = words[1] "-" words[2]
    # Remove non-alphanumeric characters from $3 and replace spaces with '-'
    gsub(/ /, "-", $3)
    gsub(/[^a-zA-Z0-9\-]/, "", $3)
    # Remove consecutive "-" in $3
    gsub(/-+/, "-", $3)
    var3 = $3
    # Output to the following variables: accession accession_name filename
    print $1,var1, var1"_"var2"_"var3
    }'
}

keep_GCX() {
    awk -v code="$prefix" 'BEGIN { FS="\t"; OFS="\t" }
    {
        # Store the relevant fields
        key = $4
        value = $1 OFS $2 OFS $3

        # Check if the key already exists in the array
        if (key in data) {
            # If it exists and the current line starts with "code_", overwrite the other
            if ($1 ~ "^" code "_") {
                data[key] = value
            }
        } else {
            # If it does not exist, add it to the array
            data[key] = value
        }
    }

    # After processing all lines, print the results
    END {
        for (key in data) {
            print data[key]
        }
    }'
}

filter_GCX() {
    awk -v code="$prefix" 'BEGIN { FS="\t"; OFS="\t" }
    {
        # Only process lines where the key starts with the specified prefix
        if ($1 ~ "^" code "_") {
            key = $4
            value = $1 OFS $2 OFS $3

            # Check if the key already exists in the array
            if (key in data) {
                # If the key exists, overwrite with the current line
                data[key] = value
            } else {
                # If it does not exist, add the key-value pair to the array
                data[key] = value
            }
        }
    }

    # After processing all lines, print the results
    END {
        for (key in data) {
            print data[key]
        }
    }'
}

# Function to update the GENOMIC directory path based on the current batch
update_genomic_dir() {
    genomic_dir="${output_dir}GENOMIC${batch_number}/"
    mkdir -p "$genomic_dir" || {
        echo "Error creating directory: $genomic_dir"
        exit 1
    }
    echo "Created/Using directory: $genomic_dir"
}

# Function to check if we can use wait -n on the current system based on the bash version
can_we_use_wait_n() {
    bash_version=$(bash --version | head -n 1 | awk '{print $4}')

    # Extract major and minor version numbers
    IFS='.' read -r major minor <<<"$bash_version"

    # Compare the major and minor versions to check if they meet the minimum requirement
    if [[ "$major" -gt 4 ]] || { [[ "$major" -eq 4 ]] && [[ "$minor" -ge 3 ]]; }; then
        echo "Bash version $bash_version meets the minimum required version (4.3)."
        can_use_wait_n=true
    else
        echo "Bash version $bash_version is too old. Minimum required version is 4.3."
        can_use_wait_n=false
    fi
}

download_and_unzip() {
    # redundant shadowing to kind of tell the input of this function
    local accession="$accession"
    local accession_name="$accession_name"
    local filename="$filename"
    local filepath="$tmp_dir""$accession_name""/"
    local complete_zip_path="$filepath""$filename.zip"
    local downloaded_path="$genomic_dir""$filename.fna"

    # Flag to download genome with api key if there is one
    api_key_flag="${api_key:+--api-key \"$api_key\"}"
    # Download files

    if [[ $keep_zip_files = "true" ]]; then
        downloaded_path="$genomic_dir""$filename.zip"
        if [ -f "$downloaded_path" ]; then
            return 0
        fi
        # Create directory for downloaded files
        mkdir -p "$filepath" || {
            echo "Error creating directory: $filepath"
            exit 1
        }
        # Download this accession
        # Directly download
        if ! "$scripts_dir"datasets download genome accession "$accession" --filename "$complete_zip_path" --include genome --no-progressbar $api_key_flag; then
            echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
            return 1
        else
            # Find the .fna file in the archive using unzip -l
            fna_file=$(unzip -l "$complete_zip_path" | awk '{print $4}' | grep '\.fna$')

            # Check if a .fna file was found
            if [[ -z "$fna_file" ]]; then
                echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
                rm "$complete_zip_path"
                return 1
            fi
            new_name=$filename.fna

            zipnote -w "$complete_zip_path" <<EOF
@ $fna_file
@=$new_name
EOF

            if ! mv -n "$complete_zip_path" "$downloaded_path"; then
                echo "**** ERROR TO MOVE contents of : " "$filepath""$archive_file/" "  in  " "$genomic_dir""$filename.fna"
            else
                rm -r "$filepath"
            fi
        fi
    elif [[ $convert_gzip_files = "true" ]]; then
        ## If we are unzipping the files
        if [ -f "$downloaded_path" ]; then
            return 0
        fi

        # Create directory for downloaded files
        mkdir -p "$filepath" || {
            echo "Error creating directory: $filepath"
            exit 1
        }
        # Download this accession
        if ! "$scripts_dir"datasets download genome accession "$accession" --filename "$complete_zip_path" --include genome --no-progressbar $api_key_flag; then
            echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
            return 1
        fi

        # Unzip genome
        archive_file="ncbi_dataset/data/$accession"
        unzip -oq "$complete_zip_path" "$archive_file""/GC*.fna" -d "$filepath"


        if ! find "$filepath""$archive_file" -type f -print0 | xargs -0 -I {} mv -n {} "$genomic_dir""$filename.fna"; then
            echo "**** ERROR TO MOVE contents of : " "$filepath""$archive_file/" "  in  " "$genomic_dir""$filename.fna"
        else
            rm -r "$filepath"
        fi
        if ! gzip "$genomic_dir""$filename.fna"; then
            echo "**** ERROR TO GZIP contents of : " "$genomic_dir""$filename.fna"
            rm "$genomic_dir""$filename.fna"
        fi
    else
        ## If we are unzipping the files
        if [ -f "$downloaded_path" ]; then
            return 0
        fi

        # Create directory for downloaded files
        mkdir -p "$filepath" || {
            echo "Error creating directory: $filepath"
            exit 1
        }
        # Download this accession
        if ! "$scripts_dir"datasets download genome accession "$accession" --filename "$complete_zip_path" --include genome --no-progressbar $api_key_flag; then
            echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
            return 1
        fi

        # Unzip genome
        archive_file="ncbi_dataset/data/$accession"
        
        unzip -oq "$complete_zip_path" "$archive_file""/GC*_genomic.fna" -d "$filepath"


        if ! find "$filepath""$archive_file" -type f -print0 | xargs -0 -I {} mv -n {} "$genomic_dir""$filename.fna"; then
            echo "**** ERROR TO MOVE contents of : " "$filepath""$archive_file/" "  in  " "$genomic_dir""$filename.fna"
        else
            rm -r "$filepath"
        fi
    fi
}

setup_data() {
    echo "TSV: " "$input_file"
    echo "Output directory for GENOMIC: " "$output_dir"

    # Create temporary and output directories
    # Initialize counters for batches and files
    batch_number=0
    file_count=0
    tmp_dir="$output_dir""tmp/"

    mkdir -p "$tmp_dir" || {
        echo "Error creating directories"
        exit 1
    }
    echo "Preferred prefix: $prefix"

    # tmp file for
    tmp_names="$tmp_dir""/tmp_names"

    can_we_use_wait_n

    if [[ -z ${api_key+x} ]]; then
        api_key=$NCBI_API_KEY
        num_process=10
        echo "Aquired NCBI API key from env"
    fi
}

num_process=3
keep_zip_files=false
convert_gzip_files=false
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
        echo "Keep zip files: $long_flag_value"
        ;;
    esac
done

# START OF SCRIPT
setup_data

# Create a named pipe (FIFO)
pipe=$(mktemp -u) # Create a temporary file name for the FIFO
mkfifo "$pipe"    # Create the named pipe

# Read the input file once into the named pipe
tail -n +2 "$input_file" >"$pipe" & # Run tail in the background

# Process the data based on the prefix
case "$prefix" in
"all")
    process_filename_redundant <"$pipe" >"$tmp_names"
    ;;
"GCA")
    process_filename <"$pipe" | keep_GCX >"$tmp_names"
    ;;
"GCF")
    process_filename <"$pipe" | filter_GCX >"$tmp_names"
    ;;
"both")
    process_filename <"$pipe" | keep_GCX >"$tmp_names"
    ;;
*)
    echo "Invalid prefix specified"
    rm -f "$pipe"
    exit 1
    ;;
esac

# Clean up: remove the named pipe
rm -f "$pipe"

while read -r accession accession_name filename; do
    # Check if we have reached the batch size
    if ((file_count % batch_size == 0)); then
        # Increment batch number and update the genomic directory
        batch_number=$((batch_number + 1))
        update_genomic_dir
    fi
    # Start download in the background
    download_and_unzip &

    # Update the file counter
    file_count=$((file_count + 1))

    # Limit the number of concurrent jobs
    if [[ $(jobs -r -p | wc -l) -ge $num_process ]]; then
        if [[ $can_use_wait_n ]]; then
            # Wait until a new job can be created
            wait -n
        else
            # Wait until batch of downloads has finished (for bash <4.2)
            wait
        fi
    fi

done <"$tmp_names"

wait
