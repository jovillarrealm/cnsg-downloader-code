#!/usr/bin/awk -f

BEGIN {
  FS = "\t"
}

NR == FNR {
  accession = $1;
  split(accession, parts, "."); # Split the accession to get the base
  base_accession = parts[1];
  exceptions[base_accession] = 1;
  next;
}

NR == 1 {
  header = $0;
  print header;
  next;
}

{
  accession = $1;
  split(accession, parts, "."); # Split the accession to get the base
  base_accession = parts[1];

  if (!(base_accession in exceptions)) {
    print $0;
  }
}