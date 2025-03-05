#!/usr/bin/awk -f

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