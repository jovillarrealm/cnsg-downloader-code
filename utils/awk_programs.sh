#!/bin/bash
process_filename() {
    awk 'BEGIN { FS="\t"; OFS="\t" } {
    # Remove version number of Assembly Accession, or $1
    split($1, arr, ".")
    var1 = arr[1]
    # Remove GCA_ GCF_
    split(var1, nodb, "_")
    var4 = nodb[2]
    # Take only first 2 words in Organism Name y eso equivale a genero y especie? and replace spaces with '-'
    gsub(/[^a-zA-Z0-9 ]/, "", $2)
    split($2, words, " ")
    var2 = words[1] "-" words[2]
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
    split($2, words, " ")
    var2 = words[1] "-" words[2]
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
    awk -v code="$prefix" '!($0 ~ "^"prefix)'
}
