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

download_and_unzip() {
    # redundant shadowing to kind of tell the input of this function
    local accession="$accession"
    local accession_name="$accession_name"
    local filename="$filename"
    local filename_ext="$filename"
    local filepath="$tmp_dir""$accession_name""/"
    local complete_zip_path="$filepath""$filename.zip"
    local downloaded_path

    # Download files

    ## Decide what the downloaded path should look like
    if [[ $keep_zip_files = "true" ]]; then
        filename="$filename.zip"
    elif [[ $convert_gzip_files = "true" ]]; then
        filename="$filename.fna.gz"
    else
        filename="$filename.fna"
    fi
    downloaded_path="$genomic_dir""$filename"

    # Skip if the file has already been downloaded
    if [ -f "$downloaded_path" ]; then
        return 0
    else
        found=$(find "$output_dir" -type f -name "$filename_ext*")
        if [ -z "${found}" ]; then
            # Remove any file with the same accession if it exists
            find "$output_dir" -type f -name "$accession*" -exec rm {} \;
        else
            return 0
        fi
    fi

    # Create directory for downloaded files
    if ! mkdir -p "$filepath"; then
        echo "Error creating directory: $filepath"
        exit 1
    fi

    # Download this accession
    # shellcheck disable=SC2086
    if ! "$utils_dir"datasets download genome accession "$accession" --filename "$complete_zip_path" --include genome${annotate:+,gff3} --no-progressbar ${api_key:+--api-key \"$api_key\"}; then
        echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
        return 1
    fi

    if [[ $keep_zip_files = "true" ]]; then

        # Find the .fna file in the archive using unzip -l
        fna_file=$(unzip -l "$complete_zip_path" | awk '{print $4}' | grep '\.fna$')

        # Check if a .fna file was found
        if [[ -z "$fna_file" ]]; then
            echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
            rm "$complete_zip_path"
            return 1
        fi

        printf "@ %s\n@=%s" "$fna_file" "$filename_ext".fna | zipnote -w "$complete_zip_path"
        if [[ $annotate = "true" ]]; then
            # Find the .gff file in the archive using unzip -l
            gff_file=$(unzip -l "$complete_zip_path" | awk '{print $4}' | grep '\.gff$')

            # Check if a .gff file was found
            if [[ -z "$gff_file" ]]; then
                echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
                rm "$complete_zip_path"
                return 1
            fi
            printf "@ %s\n@=%s" "$gff_file" "$filename_ext".gff | zipnote -w "$complete_zip_path"
        fi

        if ! mv -n "$complete_zip_path" "$downloaded_path"; then
            echo "**** ERROR TO MOVE contents of : " "$filepath" "  in  " "$downloaded_path"
        fi

    elif [[ $convert_gzip_files = "true" ]]; then
        # Find the .fna file in the archive using unzip -l
        fna_file=$(unzip -l "$complete_zip_path" | awk '{print $4}' | grep '\.fna$')

        # Check if a .fna file was found
        if [[ -z "$fna_file" ]]; then
            echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
            rm "$complete_zip_path"
            return 1
        fi

        printf "@ %s\n@=%s" "$fna_file" "$filename_ext".fna | zipnote -w "$complete_zip_path"
        unzip -oq "$complete_zip_path" "*.fna" -d "$filepath"

        # gzip the genome
        if ! gzip "$filepath""$filename_ext".fna; then
            echo "**** ERROR TO GZIP contents of : " "$genomic_dir""$filename"
            rm "$filepath""$filename_ext".fna
        fi

        if ! mv -n "$filepath""$filename_ext".fna.gz "$downloaded_path"; then
            echo "**** ERROR TO MOVE contents of : " "$filepath" "  in  " "$downloaded_path"
        fi

    else

        # Find the .fna file in the archive using unzip -l
        fna_file=$(unzip -l "$complete_zip_path" | awk '{print $4}' | grep '\.fna$')
        # Check if a .fna file was found, rename the inner fna file
        if [[ -z "$fna_file" ]]; then
            echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
            rm "$complete_zip_path"
            return 1
        fi
        printf "@ %s\n@=%s" "$fna_file" "$filename_ext".fna | zipnote -w "$complete_zip_path"
        unzip -oq "$complete_zip_path" "*.fna" -d "$filepath"
        if [[ $annotate = "true" ]]; then
            gff_file=$(unzip -l "$complete_zip_path" | awk '{print $4}' | grep '\.gff$')

            # Check if a .gff file was found
            if [[ -z "$gff_file" ]]; then
                echo "**** FAILED TO DOWNLOAD $accession , en  $complete_zip_path"
                rm "$complete_zip_path"
                return 1
            fi
            new_name=$filename_ext.gff

            printf "@ %s\n@=%s" "$gff_file" "$new_name" | zipnote -w "$complete_zip_path"
            unzip -oq "$complete_zip_path" "*.gff" -d "$filepath"
        fi

        if ! find "$filepath" -type f -name "*fna" -print0 | xargs -0 -I {} mv -n {} "$downloaded_path"; then
            echo "**** ERROR TO MOVE contents of : " "$filepath" "  in  " "$genomic_dir""$filename"
        else
            if [[ $annotate = "true" ]]; then
                find "$filepath" -type f -name "*gff" -print0 | xargs -0 -I {} mv -n {} "$gff_dir""$filename_ext.gff"
            fi
        fi
    fi

    rm -r "$filepath"
}
