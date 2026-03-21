# lib/common.nu

export def filter_exclusions [data: table, exclusions_file: any, acc_col: string] {
    let exclusions = if ($exclusions_file != null) and ($exclusions_file | path exists) {
        open $exclusions_file | lines | str trim | where ($it != "")
    } else {
        []
    }

    if ($exclusions | is-empty) {
        $data
    } else {
        $data | where { |row| ($row | get $acc_col) not-in $exclusions }
    }
}

export def filter_prefixes [data: table, prefixes: string, acc_col: string] {
    let prefix_list = ($prefixes | split row "," | str trim | where ($it != ""))
    if ($prefix_list | is-empty) {
        $data
    } else {
        $data | where { |row|
            let acc = ($row | get $acc_col)
            ($prefix_list | any { |p| $acc | str starts-with $p })
        }
    }
}

export def check_dependencies [source: string, lib_dir: string] {
    let general_deps = ["unzip", "count-fasta-rs", "uv"]
    let source_deps = if $source == "ncbi" {
        ["datasets", "dataformat"]
    } else {
        []
    }

    let all_deps = ($general_deps | append $source_deps)
    mut missing = []

    for dep in $all_deps {
        # Check if in PATH
        if (which $dep | is-empty) {
            # Check if in lib_dir
            let lib_path = ($lib_dir | path join $dep)
            if not ($lib_path | path exists) {
                $missing = ($missing | append $dep)
            }
        }
    }

    if not ($missing | is-empty) {
        error make {
            msg: $"The following dependencies are missing: ($missing | str join ', '). Please install them and try again."
        }
    }
}

export def analyze_genomes [dir_to_analyze: string, stats_file: string, lib_dir: string] {
    if not ($stats_file | path exists) {
        print $"Running count-fasta-rs on ($dir_to_analyze)..."
        try {
            run-external "count-fasta-rs" "-c" $stats_file "-d" $dir_to_analyze
        } catch {
            print "WARNING: count-fasta-rs failed or is not in PATH."
        }
    } else {
        print $"Stats file ($stats_file) already exists"
    }

    let plots_dir = ($lib_dir | path join "plots")
    let script_path = ($plots_dir | path join "plots-count-fasta.py")
    
    if ($stats_file | path exists) {
        print "Generating plots..."
        try {
            run-external "uv" "run" "--project" $plots_dir $script_path $stats_file
        } catch {
            print "WARNING: uv plot generation failed."
        }
    }
}
