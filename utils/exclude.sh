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

# Function to update the GENOMIC directory path based on the current batch.
# genomics_dir is set and exists after this

utils_dir="$(dirname "$0")"
utils_dir="$(realpath "$utils_dir")"/
: "${1:? set an output_dir}"
: "${2:? set an exclude}"
: "${3:? set a prefix}"
: "${output_dir:="$1"}"
: "${exclude:="$2"}"
: "${prefix:="$3"}"


delete_exclusions() {
    if [ -f "$exclude" ]; then
        echo "Deleting exclusions..."
        while IFS= read -r prefix; do
            prefix=$(echo "$prefix" | awk -F'.' '{print $1}')
            #echo "Processing prefix: '$prefix'"
            find "$output_dir" -type f -name "$prefix*" -print -delete # or -exec rm {} \;
        done <"$exclude"
    fi
}


delete_exclusions

