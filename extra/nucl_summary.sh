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
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
taxon=$1
title_query=$2

split_multi_fasta() {
    mkdir -p "$taxon"
    # Read the file and process it
    while IFS= read -r line; do
        if [[ $line == ">"* ]]; then
            # Extract Accession_Number, Organism, and species from the header
            header="$line"
            accession=$(echo "$header" | awk '{print $1}' | cut -d'.' -f1 | tr -d '>')
            organism=$(echo "$header" | awk '{print $2}')
            species=$(echo "$header" | awk '{print $3}' | cut -d'.' -f1)

            # Create the filename
            filename="${accession}_${organism}_${species}.fasta"

            # Write the header to the file
            echo "$header" >"$taxon/""$filename"
        else
            # Append the sequence to the file
            echo "$line" >>"$taxon/""$filename"
        fi
    done <"$input_file"
}

# Input multifasta file
input_file="${taxon}.fasta"

esearch -db nuccore -query "(\"${taxon}\"[Organism] OR ${taxon}[All Fields])) AND (${title_query}[Title] OR small subunit[Title])" |
    efetch -format fasta >"$input_file"

split_multi_fasta