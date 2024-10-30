#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/

should_renew_file() {
    if [[ -f "$file" ]]; then
        # Make a query to check if a new version exists
        command_output=$( "$scripts_dir"datasets summary genome taxon Aphelenchoides --limit 0 2>&1 1>/dev/null )  # Capture stderr output
        if [[ $command_output =~ ^"New version of client" ]]; then
            return 0  # New version detected
        else
            return 1  # No new version detected
        fi
    else
        return 0 # File does not even exist
    fi
}

file="$scripts_dir"datasets

if ! count-fasta-rs -V 1> /dev/null; then
    curl --proto '=https' --tlsv1.2 -LsSf https://github.com/jovillarrealm/count-fasta-rs/releases/download/v0.5.3/count-fasta-rs-installer.sh | sh
fi


if should_renew_file; then
    echo "ncbi datasets not found or too old, attempting to download"
    os=$(uname)
    if [ "$os" = "Linux" ]; then
        curl -o "$scripts_dir"datasets 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/datasets'
        curl -o "$scripts_dir"dataformat 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/dataformat'
        chmod +x "$scripts_dir"datasets "$scripts_dir"dataformat
        elif [ "$os" = "Darwin" ]; then
        curl -o "$scripts_dir"datasets 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/mac/datasets'
        curl -o "$scripts_dir"dataformat 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/mac/dataformat'
        chmod +x "$scripts_dir"datasets "$scripts_dir"dataformat
    fi
fi
