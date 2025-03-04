#!/bin/bash

: "${1:? set an  output path like eu}"

out_dir="$(realpath "$1")"/
scripts_dir="$(realpath "$0")"
scripts_dir="$(dirname "$scripts_dir")"
scripts_dir="$(dirname "$scripts_dir")"/
"$scripts_dir"summary_download.sh -i eubacteria -o "$out_dir" -p GCA -l 100

tsv_file=$(find "$out_dir" -maxdepth 1 -name "*latest*tsv") 
uv run --project "$scripts_dir"utils/plots/ "$scripts_dir"utils/plots/group.py "$tsv_file" "$out_dir"

find "$out_dir" -mindepth 2 -name "*tsv" -print -exec "$scripts_dir"tsv_datasets_downloader.sh -i {} -p GCA --convert-gzip-files=true \;






