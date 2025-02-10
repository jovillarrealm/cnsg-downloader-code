#!/bin/bash

scripts_dir="$(dirname "$0")"
extra_scripts_dir="$(realpath "$scripts_dir")"
scripts_dir="${extra_scripts_dir%/*}"/

gz_compare_dir=./gz-compare-output
zip_compare_dir=./zip-compare-output
mkdir -p $gz_compare_dir $zip_compare_dir

test_count_fasta_rs_vs_perl() {
    find $target_dir -type f -name "*fna" -print0 |
        xargs -0 -I {} "$extra_scripts_dir"/rs-comperl.sh {}
}

test_count_fasta_rs_gzip_files() {
    echo $target_dir
    find "$target_dir" -type f -name "*fna.gz" -exec count-fasta-rs {} \; >>$gz_compare_dir/gz.out
    find "$target_dir" -type f -name "*fna.gz" -exec gzip -d {} \;
    find "$target_dir" -type f -name "*fna" -exec count-fasta-rs {} \; >>$gz_compare_dir/plain.out
    sort -r $gz_compare_dir/gz.out > $gz_compare_dir/gz_s.out
    sort -r $gz_compare_dir/plain.out > $gz_compare_dir/plain_s.out
    diff -w $gz_compare_dir/gz_s.out $gz_compare_dir/plain_s.out >>$gz_compare_dir/diff_file
}

test_count_fasta_rs_zip_files() {
    echo $target_dir
    find "$target_dir" -maxdepth 2 -type f -name "*zip" -exec count-fasta-rs {} \; >> $zip_compare_dir/zip.out
    sort -r $zip_compare_dir/zip.out > $zip_compare_dir/zip_s.out
    find "$target_dir" -type f -name "*zip" -print0 | xargs -0 -I {} unzip -q -o -d "$target_dir" {} "*.fna"
    find "$target_dir" -type f -name "*fna" -exec count-fasta-rs {} \; >>$zip_compare_dir/plain.out
    sort -r $zip_compare_dir/plain.out > $zip_compare_dir/plain_s.out
    diff -w $zip_compare_dir/zip_s.out $zip_compare_dir/plain_s.out >>$zip_compare_dir/diff_file
}

target_dir="./Aphelenchoides"
"$scripts_dir"genome_download.sh -i Aphelenchoides -o "$target_dir" -p GCA -l 30
test_count_fasta_rs_vs_perl


target_dir="./Aphelenchoideszip"
"$scripts_dir"genome_download.sh -i Aphelenchoides -o "$target_dir" -p GCA -l 30 --keep-zip-files=true
test_count_fasta_rs_zip_files

target_dir="./Aphelenchoidesgzip"
"$scripts_dir"genome_download.sh -i Aphelenchoides -o "$target_dir" -p GCA -l 30 --convert-gzip-files=true
test_count_fasta_rs_gzip_files

target_dir="./Strepto"
"$scripts_dir"genome_download.sh -i Streptomyces -o "$target_dir" -p GCF -l 30
test_count_fasta_rs_vs_perl


target_dir="./Streptozip"
"$scripts_dir"genome_download.sh -i Streptomyces -o "$target_dir" -p all -l 30 -b 15 --keep-zip-files=true
test_count_fasta_rs_zip_files

target_dir="./Streptogzip"
"$scripts_dir"genome_download.sh -i Streptomyces -o "$target_dir" -p GCF -l 30 -b 10 --convert-gzip-files=true
test_count_fasta_rs_gzip_files
