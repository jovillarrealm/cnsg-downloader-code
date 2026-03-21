# lib/ncbi.nu
use common.nu

def get_cli_path [name: string, lib_dir: string] {
    let in_path = (which $name)
    if not ($in_path | is-empty) {
        return $name
    } else {
        return ($lib_dir | path join $name)
    }
}

export def download [
    query: string
    query_type: string
    output_dir: string
    prefixes: string
    exclusions_file: any
    batch_size: int
    reference: bool
    limit: any
    convert_gzip: bool
    annotate: bool
    today: string
    lib_dir: string
] {
    let datasets_bin = (get_cli_path "datasets" $lib_dir)
    let dataformat_bin = (get_cli_path "dataformat" $lib_dir)

    let api_key = ($env.NCBI_API_KEY? | default "")
    if ($api_key | is-empty) {
        print "WARNING: No NCBI API key found. Throttling may occur."
    } else {
        print "INFO: Using NCBI API key."
    }

    let safe_query_name = ($query | str replace -a ' ' '_')
    let download_file = ($output_dir | path join $"($safe_query_name)_($today)_latest.tsv")

    if not ($download_file | path exists) {
        print "Fetching summary from NCBI datasets..."
        
        let target_type = if $query_type == "bioproject" { "accession" } else { "taxon" }
        
        mut datasets_args = [
            "summary", "genome", $target_type, $query,
            "--assembly-source", "all",
            "--assembly-version", "latest",
            "--mag", "exclude",
            "--as-json-lines"
        ]

        if not ($api_key | is-empty) { $datasets_args = ($datasets_args | append ["--api-key", $api_key]) }
        if $reference { $datasets_args = ($datasets_args | append ["--reference"]) }
        if ($limit != null) { $datasets_args = ($datasets_args | append ["--limit", ($limit | into string)]) }

        let summary_json = (run-external $datasets_bin ...$datasets_args)
        let tsv_output = ($summary_json | run-external $dataformat_bin "tsv" "genome" "--fields" "accession,organism-name,organism-infraspecific-strain,assmstats-total-sequence-len,assmstats-number-of-contigs,assmstats-contig-n50,assmstats-gc-count,assmstats-gc-percent")
        
        $tsv_output | save -f $download_file
    } else {
        print $"Summary file ($download_file) already exists."
    }

    let summary_data = (open --raw $download_file | from tsv)
    let filtered_by_exclusions = (common filter_exclusions $summary_data $exclusions_file "Assembly Accession")
    let filtered_summary = (common filter_prefixes $filtered_by_exclusions $prefixes "Assembly Accession")

    let accessions = ($filtered_summary | get "Assembly Accession")
    
    if ($accessions | is-empty) {
        print "No accessions found to download. Exiting."
        return
    }

    let acc_file = ($output_dir | path join $"($safe_query_name)_accessions.txt")
    $accessions | str join (char newline) | save -f $acc_file

    let zip_filename = ($output_dir | path join $"($safe_query_name)_dehydrated.zip")
    
    print "Downloading dehydrated package..."
    mut download_args = [
        "download", "genome", "accession",
        "--inputfile", $acc_file,
        "--dehydrated",
        "--filename", $zip_filename
    ]
    if not ($api_key | is-empty) { $download_args = ($download_args | append ["--api-key", $api_key]) }
    if $annotate { $download_args = ($download_args | append ["--include", "gff3,rna,protein,genome,seq-report"]) }
    
    run-external $datasets_bin ...$download_args

    print "Unzipping dehydrated package..."
    let extract_dir = ($output_dir | path join $"($safe_query_name)_extracted")
    mkdir $extract_dir
    run-external "unzip" "-q" "-o" $zip_filename "-d" $extract_dir

    print "Rehydrating files..."
    let max_workers = if not ($api_key | is-empty) { "30" } else { "10" }
    
    mut rehydrate_args = [
        "rehydrate",
        "--directory", $extract_dir,
        "--max-workers", $max_workers
    ]
    if not ($api_key | is-empty) { $rehydrate_args = ($rehydrate_args | append ["--api-key", $api_key]) }
    if $convert_gzip { $rehydrate_args = ($rehydrate_args | append ["--gzip"]) }

    run-external $datasets_bin ...$rehydrate_args
    print "Rehydration complete."

    let stats_file = ($output_dir | path join $"($safe_query_name)_($today)_stats.csv")
    common analyze_genomes $extract_dir $stats_file $lib_dir
}
