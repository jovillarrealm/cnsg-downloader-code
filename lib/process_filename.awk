#!/usr/bin/awk -f

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


BEGIN { FS="\t"; OFS="\t" } {
    # Remove version number of Assembly Accession, or $1
    split($1, arr, ".")
    var1 = arr[1]
    # Remove GCA_ GCF_
    split(var1, nodb, "_")
    var4 = nodb[2]
    # Take only first 2 words in Organism Name and replace spaces with '-'
    if ($2 ~ /^candidate division /) { # Handle candidate division as Candidatus
        split($2, words, " ")
        var2 = "Candidatus" "-" words[2] "-" words[3]
    } else if ($2 ~ /^Candidatus /) { # Handle Candidatus
        split($2, words, " ")
        var2 = words[1] "-" words[2] "-" words[3]
    } else if ($2 ~ /aff\. /) { # Handle aff.
        gsub(/aff\. /, "", $2);
        split($2, words, " ")
        var2 = "DUD" "-" words[1] "-" words[2]
    } else if ($2 ~ /cf\. /) { # Handle cf.
        gsub(/cf\. /, "", $2); 
        split($2, words, " ")
        var2 = "DUD" "-" words[1] "-" words[2]
    } else if ($2 ~ /^\[.*\]/) { # Handle brackets
        gsub(/[^a-zA-Z0-9 ]/, "", $2)
        split($2, words, " ")
        var2 = "DUD" "-" words[1] "-" words[2]
    } else if ($2 ~ /^'.*'/) { # Added for quotes
        gsub(/[^a-zA-Z0-9 ]/, "", $2) # Remove non-alphanumeric except space
        split($2, words, " ")
        var2 = "DUD" "-" words[1] "-" words[2]
    } else {
        gsub(/[^a-zA-Z0-9 ]/, "", $2)
        split($2, words, " ")
        var2 = words[1] "-" words[2]
    }
    # var2 Cleanup
    gsub(/[^a-zA-Z0-9\-]/, "", var2)
    gsub(/-+/, "-", var2)
    # Remove non-alphanumeric characters from $3 and replace spaces with '-'
    gsub(/ /, "-", $3)
    gsub(/[^a-zA-Z0-9\-]/, "", $3)
    # Remove consecutive "-" in $3
    gsub(/-+/, "-", $3)
    var3 = $3
    # Output to the following variables: accession accession_name filename sans_GC
    print $1,var1, var1"_"var2"_"var3, var4
}
