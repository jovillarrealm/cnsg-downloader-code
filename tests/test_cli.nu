# tests/test_cli.nu
use std assert

def get_script_path [] {
    ($env.FILE_PWD | path join ".." "genome_downloader.nu" | path expand)
}

def main [] {
    test_cli_help
    test_invalid_source
    print "All CLI tests passed!"
}

def test_cli_help [] {
    print "Testing CLI help command..."
    let script = (get_script_path)
    let help_res = (do { ^nu $script "--help" } | complete)
    assert ($help_res.exit_code == 0)
    assert ($help_res.stdout | str contains "Downloads genomic data from NCBI or EBI")
    print "test_cli_help passed"
}

def test_invalid_source [] {
    print "Testing invalid source flag..."
    let script = (get_script_path)
    let source_res = (do { ^nu $script "Taxon" "--source" "invalid_backend" } | complete)
    assert ($source_res.exit_code != 0)
    assert ($source_res.stderr | str contains "Invalid source")
    print "test_invalid_source passed"
}
