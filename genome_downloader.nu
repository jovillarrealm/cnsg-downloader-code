#!/usr/bin/env nu

use lib/ncbi.nu
use lib/ebi.nu
use lib/common.nu

# Downloads genomic data from NCBI or EBI based on a taxon name, BioProject, or ID.
#
# Use --check-api-key to see if an NCBI API key is currently detected.
def main [
    query: string = ""       # Search term: Taxon name, NCBI Taxonomy ID, or BioProject accession (e.g., 'Aphelenchoides' or 'PRJNA31257')
    --query-type (-q): string = "taxon" # Type of query provided: 'taxon' (default) or 'bioproject'
    --output (-o): string = "./"  # Path to the directory where data will be stored
    --prefixes (-p): string = ""  # Comma-separated list of prefixes to filter by (e.g., 'GCF,GCA' for NCBI or 'ERZ' for EBI). If empty, all are downloaded. (default: '')
    --exclusions-file (-e): string # Path to an exclusions file
    --batch-size (-b): int = 50000 # Number of files in each GENOMIC folder
    --reference (-r)               # Downloads only reference genomes
    --limit (-l): int              # Limits the summary to the first NUMBER of genomes
    --convert-gzip-files           # Keeps downloaded genomes as gzip files instead of recompressing them
    --annotate                     # Adds GFF annotations to a separate directory
    --source (-s): string = "ncbi" # Data source: 'ncbi' or 'ebi'
    --check-api-key                # Check if an NCBI API key is found in the environment and exit
] {
    if $check_api_key {
        let has_ncbi = ($env.NCBI_API_KEY? != null)
        if $has_ncbi {
            print "NCBI_API_KEY: FOUND"
        } else {
            print "NCBI_API_KEY: NOT FOUND"
        }
        return
    }

    if ($query | is-empty) {
        # Trigger help if no query is provided and not checking api key
        error make {msg: "Please provide a query (taxon or bioproject). See --help for more information."}
    }

    if ($query_type != "taxon" and $query_type != "bioproject") {
        error make {msg: "Invalid query-type. Please specify 'taxon' or 'bioproject'."}
    }

    let scripts_dir = ($env.FILE_PWD | path expand)
    let lib_dir = ($scripts_dir | path join "lib")
    let output_dir = ($output | path expand)

    # API Key Environment Check (Logging)
    let has_ncbi = ($env.NCBI_API_KEY? != null)
    print $"(char newline)Environment API Key Check:"
    print $"  NCBI [NCBI_API_KEY]: (if $has_ncbi { 'FOUND' } else { 'NOT FOUND' })"
    print $"  EBI: No key required for public access(char newline)"

    # Pre-flight check for dependencies
    common check_dependencies $source $lib_dir
    
    # Ensure output directory exists
    mkdir $output_dir

    let today = (date now | format date "%d-%m-%Y")

    print $"(char newline)** STARTING (($source | str upcase)) DOWNLOAD FOR ($query_type | str upcase): ($query) **(char newline)"
    let start_time = (date now)

    if $source == "ncbi" {
        ncbi download $query $query_type $output_dir $prefixes $exclusions_file $batch_size $reference $limit $convert_gzip_files $annotate $today $lib_dir
    } else if $source == "ebi" {
        ebi download $query $query_type $output_dir $prefixes $limit $today $lib_dir
    } else {
        error make {msg: "Invalid source. Please specify 'ncbi' or 'ebi'."}
    }

    let end_time = (date now)
    let elapsed = ($end_time - $start_time)
    print $"(char newline)** DONE in ($elapsed) **(char newline)"
}
