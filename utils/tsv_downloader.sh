#!/bin/bash

# Function to update the GENOMIC directory path based on the current batch. 
# genomics_dir is set and exists after this
update_dir_count() {
    genomic_dir="${output_dir}GENOMIC${batch_number}/"
    mkdir -p "$genomic_dir" || {
        echo "Error creating directory: $genomic_dir"
        exit 1
    }
    if [[ $annotate = "true" ]]; then
        gff_dir="${output_dir}GFF${batch_number}/"
        mkdir -p "$gff_dir" || {
            echo "Error creating directory: $gff_dir"
            exit 1
        }
    fi
    echo "Created/Using directory: $genomic_dir"
}

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

# Function to process the TSV file based on the specified prefix, output written to tmp_names
process_tsv() {

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
        prefix="GCA"
        process_filename <"$pipe" | filter_out_GCX >"$tmp_names"
        prefix="GCF"
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

    process_tsv

    : "${api_key:=$NCBI_API_KEY}"
    if [[ -z ${api_key+x} ]]; then
        num_process=10
    fi
}

