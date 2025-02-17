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

os=$(uname)
utils_dir="$(dirname "$0")"
utils_dir="$(realpath "$utils_dir")"/


should_renew_file() {
    if [[ -f "$utils_dir"datasets ]] && [[ -f "$utils_dir"dataformat ]]; then
        # Make a query to check if a new version exists
        command_output=$("$utils_dir"datasets summary genome taxon Aphelenchoides --limit 0 2>&1 1>/dev/null) # Capture stderr output
        if [[ $command_output =~ ^"New version of client" ]]; then
            return 0 # New version detected
        else
            return 1 # No new version detected
        fi
    else
        return 0 # File does not even exist
    fi
}

if ! count-fasta-rs -V 1>/dev/null 2>/dev/null; then
    curl --proto '=https' --tlsv1.2 -LsSf https://github.com/jovillarrealm/count-fasta-rs/releases/download/v0.6.1/count-fasta-rs-installer.sh | sh
    if [ "$os" = "Darwin" ]; then
        curl --proto '=https' --tlsv1.2 -LsSf https://github.com/jovillarrealm/count-fasta-plots/releases/download/v0.1.4/count-fasta-plots-installer.sh | sh
    fi
fi

if should_renew_file; then
    echo "ncbi datasets not found or too old, attempting to download"
    if [ "$os" = "Linux" ]; then
        curl -o "$utils_dir"datasets 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/datasets'
        curl -o "$utils_dir"dataformat 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/dataformat'
        chmod +x "$utils_dir"datasets "$utils_dir"dataformat
    elif [ "$os" = "Darwin" ]; then
        curl -o "$utils_dir"datasets 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/mac/datasets'
        curl -o "$utils_dir"dataformat 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/mac/dataformat'
        chmod +x "$utils_dir"datasets "$utils_dir"dataformat
    fi
fi
