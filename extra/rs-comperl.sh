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

out_dir=./rs-comperl-output/
mkdir -p $out_dir

tmp_dir=/tmp/
diff_file="$out_dir""diff_file"
diffs_file="$out_dir""diffs_file"

tmperlfile="$out_dir""tmperlfile"
tmprsfile="$out_dir"tmpfile-rs

scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/

"$scripts_dir"count_fasta_cnsg.pl -i 100 "$1" > "$tmperlfile" 2> /dev/null
tail -n 13 "$tmperlfile" > "$tmp_dir"tmpfile && mv "$tmp_dir"tmpfile "$tmperlfile"

count-fasta-rs "$1" > "$tmprsfile"

diff -w "$tmperlfile" "$tmprsfile" > "$diff_file"

lines=$(wc -l "$diff_file" | awk '{print $1}')
if [[ "$lines" -gt 1  ]]
then
    echo "We have a problem:"
    echo "$1"
    cat "$diff_file" >> "$diffs_file"
else
    true
fi