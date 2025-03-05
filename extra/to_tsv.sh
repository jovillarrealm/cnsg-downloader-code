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


print_help() {
    echo ""
    echo "Usage: $0 list_file <delimiter> <tsv>"
    echo ""
    echo ""
    echo "Arguments:"
    echo "list_file is a file containig a list with the following format"
    echo "delimiter is the character that serves to separate items [Default: _]"
    echo "output is the path of the resulting tsv [Default: {list_file}.tsv]"
    echo ""
    echo "GCF_011040455_Bacillus_tropicus_"
    echo "GCF_020809245_Bacillus_thuringiensis_"
    echo "GCF_000717535_Bacillus_thuringiensis_serovar_kurstaki_str_HD-1_"
    echo ""
    echo ""
    echo "And outputs a tsv that looks like this:"
    echo "GCF_011040455	Bacillus-tropicus"
    echo "GCF_020809245	Bacillus-thuringiensis	"
    echo "GCF_000717535	Bacillus-thuringiensis	serovar-kurstaki-str-HD-1-"
    echo ""
    echo ""
    echo ""
    echo ""
}
delimiter="${2:-_}"
output="${3:-"$1".tsv}"

if [[ $# -lt 1 ]]; then
    print_help
    exit 1
fi

underscore_to_tsv() {
    echo "Assembly Accession	Assembly Name	Organism Name" >"$output"
    awk -v separator="$delimiter" 'BEGIN { FS=separator; OFS="\t" }
    {
        gsub(/\.[^.]*$/, "", $0)
        first_two = $1 "_" $2
        next_two = $3 "-" $4
        remaining = ""
        for (i = 5; i <= NF; i++) {
            remaining = (remaining == "" ? $i : remaining "-" $i)
        }
        print first_two, next_two, remaining
    }' "$1" >>"$output"
}

filelist_to_tsv() {
    echo "Assembly Accession	Assembly Name	Organism Name" >"$output"
    awk -v separator="$delimiter" 'BEGIN { FS="_"; OFS="\t" }
    {
        gsub(/\.[^.]*$/, "", $0)
        first_two = $1 "_" $2
        print first_two, $3, $4
    }' "$1" >>"$output"
}

if [[ "$delimiter" != "file" ]]; then
    underscore_to_tsv "$@"
elif [[ "$delimiter" = "file" ]]; then
    filelist_to_tsv "$@"
fi
