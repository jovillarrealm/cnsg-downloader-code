# lib/ebi.nu
use common.nu

export def download [
    query: string
    query_type: string
    output_dir: string
    prefixes: string
    limit: any
    today: string
    lib_dir: string
] {
    print "Fetching ENA Portal API for EBI accessions..."
    
    let encoded_query = ($query | url encode)
    let api_query_part = if $query_type == "bioproject" {
        $"study_accession=%22($encoded_query)%22"
    } else {
        $"tax_name=%22($encoded_query)%22"
    }

    let url = $'https://www.ebi.ac.uk/ena/portal/api/search?result=analysis&query=($api_query_part)%20AND%20analysis_type=%22SEQUENCE_ASSEMBLY%22&fields=accession,tax_id,scientific_name,submitted_ftp&format=tsv&limit=' + ($limit | default 0 | into string)

    print $"Querying: ($url)"
    let result = (run-external "curl" "-s" $url)

    if ($result | is-empty) {
        print "No EBI data found for this query."
        return
    }

    let safe_query_name = ($query | str replace -a ' ' '_')

    # Save summary
    let summary_file = ($output_dir | path join $"($safe_query_name)_ebi_($today).tsv")
    $result | save -f $summary_file
    print $"Saved EBI summary to ($summary_file)"

    let ebi_data = ($result | from tsv)
    let filtered_ebi_data = (common filter_prefixes $ebi_data $prefixes "accession")

    if ("submitted_ftp" not-in ($filtered_ebi_data | columns)) {
         print "No submitted_ftp column found in EBI response."
         return
    }

    let ftp_links = ($filtered_ebi_data | get submitted_ftp | split row ";" | where ($it != ""))
    if ($ftp_links | is-empty) {
        print "No FTP links available to download."
        return
    }

    let download_dir = ($output_dir | path join $"($safe_query_name)_ebi_downloads")
    mkdir $download_dir

    print $"Downloading ($ftp_links | length) EBI files via parallel HTTP..."

    $ftp_links | par-each { |ftp|
        let file_name = ($ftp | split row "/" | last)
        let out_path = ($download_dir | path join $file_name)
        if not ($out_path | path exists) {
            print $"Downloading ($file_name)..."
            let full_url = if ($ftp | str starts-with "ftp.ebi.ac.uk") {
                $"http://($ftp)"
            } else {
                $ftp
            }
            try {
                http get $full_url | save -f $out_path
            } catch {
                print $"Failed to download ($full_url)"
            }
        } else {
            print $"Skipping ($file_name), already exists."
        }
    }
    print "EBI downloads complete."

    let stats_file = ($output_dir | path join $"($safe_query_name)_ebi_($today)_stats.csv")
    common analyze_genomes $download_dir $stats_file $lib_dir
}
