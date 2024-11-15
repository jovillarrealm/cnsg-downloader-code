#!/bin/bash

os=$(uname)
scripts_dir="$(dirname "$0")"
scripts_dir="$(realpath "$scripts_dir")"/
taxon=$1
title_query=$2

esearch -db nuccore -query "(\"${taxon}\"[Organism] OR ${taxon}[All Fields])) AND (${title_query}[Title] OR small subunit[Title])" | efetch -format fasta >"${taxon}.fasta"

