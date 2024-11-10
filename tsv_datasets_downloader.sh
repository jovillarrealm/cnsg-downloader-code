#!/bin/bash

batch_size=50000
prefix="both"
output_dir=./
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/

print_help() {
    echo ""
    echo "Usage: $0 -i tsv/input/file/path [-o path/for/dir/GENOMIC] [-a path/to/api/key/file] [-p preferred prefix]"
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
    echo "This script assumes 'datasets' and 'dataformat' are in PATH"
    echo "It uses unzip, awk, xargs, datasets, dataformat"
    echo ""
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
    local complete_zip_path="$filepath""$accession_name.zip"
    local downloaded_path="$genomic_dir""$filename.fna"
    # Download files
    if [ -f "$downloaded_path" ]; then
        return 0
    else

        # Create directory for downloaded files
        mkdir -p "$filepath" || {
            echo "Error creating directory: $filepath"
            exit 1
        }

        # Download genome with api key if there is one
        if [ "$num_process" -eq 3 ]; then
            if ! "$scripts_dir"datasets download genome accession "$accession" --filename "$complete_zip_path" --include genome --no-progressbar; then # || { echo "Error downloading genome: $accession"; exit 1; }
                echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
                return 1
            fi
        else
            if ! "$scripts_dir"datasets download genome accession "$accession" --filename "$complete_zip_path" --include genome --no-progressbar --api-key "$api_key"; then # || { echo "Error downloading genome: $accession"; exit 1; }
                echo "**** ERROR TO DOWNLOAD $accession , en  $complete_zip_path"
                return 1
            fi
        fi

        # Unzip genome
        archive_file="ncbi_dataset/data/$accession"
        searchpath="$filepath""$archive_file"
        unzip -oq "$complete_zip_path" "$archive_file""/GC*_genomic.fna" -d "$filepath"

        # Move extracted fasta to desired location
        extracted=$(find "$searchpath" -name "*" -type f)
        extension="${extracted##*.}"
        if ! find "$filepath""$archive_file" -type f -print0 | xargs -0 -I {} mv -n {} "$genomic_dir""$filename.$extension"; then
            echo "**** ERROR TO MOVE contents of : " "$filepath""$archive_file/" "  in  " "$genomic_dir""$filename.$extension"
        else
            # Cleanup temp files
            if $delete_tmp; then
                rm -r "$filepath"
            fi
        fi
    fi
}

setup_data() {
    echo "TSV: ""$input_file"
    echo "Output directory for GENOMIC: ""$output_dir"

    # Create temporary and output directories
    # Initialize counters for batches and files
    batch_number=1
    file_count=0
    tmp_dir="$output_dir""tmp/"
    update_genomic_dir

    mkdir -p "$tmp_dir" "$genomic_dir" || {
        echo "Error creating directories"
        exit 1
    }
    echo "Created: " "$tmp_dir"
    echo "Created: " "$genomic_dir"
    echo "Preferred prefix: $prefix"

    # tmp file for
    tmp_names="$tmp_dir""/tmp_names"

    can_we_use_wait_n
    if [ -z ${api_key+x} ]; then
        api_key=$NCBI_API_KEY
        echo "Aquired NCBI API key from env"
    fi
}

delete_tmp=true
num_process=3
while getopts ":h:p:i:o:a:b:" opt; do
    case "${opt}" in
    i)
        input_file="${OPTARG}"
        ;;
    o)
        output_dir=$(realpath "${OPTARG}")"/"
        ;;
    a)
        api_key_file="${OPTARG}"
        echo "API Key en archivo: ""${api_key_file}"" se van a poder, máximo 10 descargas a la vez"
        api_key=$(cat "${OPTARG}")
        num_process=6
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

# START OF SCRIPT

setup_data

if [ "$prefix" = "all" ]; then
    tail -n +2 "$input_file" |
        process_filename_redundant >"$tmp_names"
elif [ "$prefix" = "GCA" ]; then
    tail -n +2 "$input_file" |
        process_filename |
        keep_GCX >"$tmp_names"
elif [ "$prefix" = "GCF" ]; then
    tail -n +2 "$input_file" |
        process_filename |
        filter_GCX >"$tmp_names"
elif [ "$prefix" = "both" ]; then
    tail -n +2 "$input_file" |
        process_filename |
        keep_GCX >"$tmp_names"
else
    echo "Invalid prefix specified"
    exit 1
fi

while read -r accession accession_name filename; do
    # Start download in the background
    download_and_unzip &

    # Update the file counter
    file_count=$((file_count + 1))

    # Check if we have reached the batch size
    if ((file_count % batch_size == 0)); then
        # Increment batch number and update the genomic directory
        batch_number=$((batch_number + 1))
        update_genomic_dir
    fi

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
