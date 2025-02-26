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
: "${1:? set an input filepath}"
: "${2:? set an tmp_file_path}"
: "${3:? set a prefix}"
: "${input_file:="$1"}"
: "${tmp_names:="$2"}"
: "${prefix:="$3"}"

process_filename() {
    awk 'BEGIN { FS="\t"; OFS="\t" } {
    # Remove version number of Assembly Accession, or $1
    split($1, arr, ".")
    var1 = arr[1]
    # Remove GCA_ GCF_
    split(var1, nodb, "_")
    var4 = nodb[2]
    # Take only first 2 words in Organism Name and replace spaces with '-'
    if ($2 ~ /\[.*\]/) {
        gsub(/[^a-zA-Z0-9 ]/, "", $2)
        # If brackets are found, add "DUD" prefix
        split($2, words, " ")
        var2 = "DUD" "-" words[1] "-" words[2]
    } else {
        gsub(/[^a-zA-Z0-9 ]/, "", $2)
        # Otherwise, extract the first two words normally
        split($2, words, " ")
        var2 = words[1] "-" words[2]
    }
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
    if ($2 ~ /\[.*\]/) {
        # If brackets are found, add "DUD" prefix
        split($2, words, " ")
        var2 = "DUD-" words[1] "-" words[2]
    } else {
        # Otherwise, extract the first two words normally
        split($2, words, " ")
        var2 = words[1] "-" words[2]
    }
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

filter_out_GCX() {
    awk -v code="$prefix" 'BEGIN { OFS="\t" } !($0 ~ "^"code) { print $1, $2, $3 }'
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

process_tsv