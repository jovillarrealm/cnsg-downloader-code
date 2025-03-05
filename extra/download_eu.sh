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
    local script_name=$(basename "$0")

    echo ""
    echo "Usage: $script_name output_path [limit]"
    echo "This script downloads all the eubacteria genomes. (Taxonomy ID: 2) For the entire superkingdom."
    echo ""
}

if [[ $# -lt 2 ]]; then
    print_help
    exit 1
fi
: "${1:? set an  output path like eu}"

date_format='%d-%m-%Y'
today="$(date +$date_format)"



out_dir="$(realpath "$1")"/
scripts_dir="$(realpath "$0")"
scripts_dir="$(dirname "$scripts_dir")"
scripts_dir="$(dirname "$scripts_dir")"/

utils_dir="$scripts_dir"utils/

plots_dir="$utils_dir"plots/


"$scripts_dir"summary_download.sh -i eubacteria -o "$out_dir" -p GCA ${2:+-l $2}

tsv_file=$(find "$out_dir" -maxdepth 1 -name "*latest*tsv") 
uv run --project "$scripts_dir"utils/plots/ "$scripts_dir"utils/plots/group.py "$tsv_file" "$out_dir"

find "$out_dir" -mindepth 2 -name "*tsv" -exec "$scripts_dir"tsv_datasets_downloader.sh -i {} -p GCA --convert-gzip-files=true \;
find "$out_dir" -mindepth 2 -name "tmp" -type d -exec rm -fr {} \;

find "$out_dir" -mindepth 2 -type d | while IFS= read -r dir; do
  taxon_dir=$(dirname "$dir")
  taxon=$(basename "$taxon_dir")
  echo "Processing Taxon: $taxon"
  stats_file="$taxon_dir"/"$taxon"_"$today"_stats.csv
  count-fasta-rs -d "$dir" -c "$stats_file"
  uv run --project "$plots_dir" "$plots_dir"plots-count-fasta.py "$stats_file"
done



