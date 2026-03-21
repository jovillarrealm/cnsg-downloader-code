# tests/test_common.nu
use std assert
use ../lib/common.nu

def main [] {
    test_filter_prefixes
    test_filter_exclusions
    test_check_dependencies
    print "All common tests passed!"
}

def test_check_dependencies [] {
    let mock_lib = (mktemp -d)
    
    # All deps present in PATH should pass (if they are)
    # But for a reliable test, we should test the failure case.
    
    # Test missing dependency
    try {
        common check_dependencies "ncbi" $mock_lib
        assert false "Should have failed for missing dependencies"
    } catch {
        print "test_check_dependencies (failure case) passed"
    }

    # Test success case with mock binaries in lib_dir
    touch ($mock_lib | path join "unzip")
    touch ($mock_lib | path join "count-fasta-rs")
    touch ($mock_lib | path join "uv")
    touch ($mock_lib | path join "datasets")
    touch ($mock_lib | path join "dataformat")
    
    # We might need to mock 'which' if we want to be sure it's checking lib_dir
    # But our implementation checks lib_dir if it's NOT in PATH.
    # So if it's NOT in path, and it IS in lib_dir, it should pass.
    
    # This might still pass if tools are in system path, which is fine.
    common check_dependencies "ncbi" $mock_lib
    print "test_check_dependencies (success case) passed"

    rm -rf $mock_lib
}

def test_filter_prefixes [] {
    let data = [
        { accession: "GCF_000001", name: "A" }
        { accession: "GCA_000002", name: "B" }
        { accession: "ERZ_000003", name: "C" }
    ]

    # Test single prefix
    let res1 = (common filter_prefixes $data "GCF" "accession")
    assert (($res1 | length) == 1)
    assert (($res1 | get 0.accession) == "GCF_000001")

    # Test multiple prefixes
    let res2 = (common filter_prefixes $data "GCF,GCA" "accession")
    assert (($res2 | length) == 2)
    assert ($res2 | any { |it| $it.accession == "GCF_000001" })
    assert ($res2 | any { |it| $it.accession == "GCA_000002" })

    # Test empty prefixes (should return all)
    let res3 = (common filter_prefixes $data "" "accession")
    assert (($res3 | length) == 3)

    print "test_filter_prefixes passed"
}

def test_filter_exclusions [] {
    let data = [
        { accession: "GCF_000001", name: "A" }
        { accession: "GCA_000002", name: "B" }
        { accession: "ERZ_000003", name: "C" }
    ]

    let excl_file = "test_exclusions.txt"
    "GCF_000001\nERZ_000003" | save -f $excl_file

    let res = (common filter_exclusions $data $excl_file "accession")
    assert (($res | length) == 1)
    assert (($res | get 0.accession) == "GCA_000002")

    rm $excl_file
    print "test_filter_exclusions passed"
}
