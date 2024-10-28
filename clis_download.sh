#!/bin/bash

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/

should_renew_file() {
    if [[ -f "$file" ]]; then
        local now_seconds
        now_seconds=$(date +%s)
        local creation_seconds
        creation_seconds=$(stat -c %Y "$file")
        local age_in_seconds=$((now_seconds - creation_seconds))
        local age_in_days=$((age_in_seconds / 86400))
        
        if [[ $age_in_days -gt 7 ]]; then
            return 0  # File is older than 7 days
        else
            return 1  # File is not older than 7 days
        fi
    else
        return 0 # File does not even exist
    fi
}

file="$scripts_dir"datasets

if ! count-fasta-rs -V; then
    curl --proto '=https' --tlsv1.2 -LsSf https://github.com/jovillarrealm/count-fasta-rs/releases/download/v0.5.3/count-fasta-rs-installer.sh | sh
fi


if should_renew_file; then
    echo "ncbi datasets not found or too old, attempting to download"
    curl -o "$scripts_dir"datasets 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/datasets'
    curl -o "$scripts_dir"dataformat 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/dataformat'
    chmod +x "$scripts_dir"datasets "$scripts_dir"dataformat
fi
