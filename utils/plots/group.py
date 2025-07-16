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

import polars as pl
import re
import os


import argparse


def dir_path(path):
    if os.path.isdir(path):
        return path
    else:
        raise argparse.ArgumentTypeError(f"readable_dir:{path} is not a valid path")


def afile_path(path):
    if os.path.isfile(path):
        return path
    else:
        raise argparse.ArgumentTypeError(f"readable_dir:{path} is not a valid path")


def process_and_save_group(group_df: pl.DataFrame):
    group_value = group_df["genus"][0].replace(" ", "-")
    # Example: modify value2 by multiplying by 2
    modified_df = group_df.select(
        [
            pl.col("Assembly Accession"),
            pl.col("Organism Name"),
            pl.col("Organism Infraspecific Names Strain"),
            pl.col("Assembly Stats Total Sequence Length"),
            pl.col("Assembly Stats Number of Contigs"),
            pl.col("Assembly Stats Contig N50"),
            pl.col("Assembly Stats GC Count"),
            pl.col("Assembly Stats GC Percent"),
        ]
    )
    # print(modified_df)
    # create the file name.
    os.makedirs(f"{output_d}/{group_value}", exist_ok=True)
    file_name = f"{output_d}/{group_value}/{group_value}_{date}.tsv"
    # save the file.
    modified_df.write_csv(file_name, separator="\t")

    return group_df


def extract_date_from_filename(filename):
    """
    Extracts the date from a filename in the format "eubacteria_26-02-2025_latest.tsv"
    or "eubacteria_26-02-2025.tsv".

    Args:
      filename: The filename string.

    Returns:
      The extracted date string in the format "DD/MM/YYYY" or None if no date is found.
    """
    match = re.search(r"\d{2}-\d{2}-\d{4}", filename)
    if match:
        date_str = match.group(0)
        return date_str
    else:
        return None
    
parser = argparse.ArgumentParser()
parser.add_argument(
    "input_file",
    type=afile_path,
    help="The input file to process, in the format 'eubacteria_26-02-2025_latest.tsv' or 'eubacteria_26-02-2025.tsv'.",
)
parser.add_argument(
    "output_directory",
    type=dir_path,
    help="The output directory where the processed files will be saved.",
)
#parser.add_argument("--dryrun", help="preview the output without creating files",
#                    action="store_true")
args = parser.parse_args()


output_d = os.path.abspath(args.output_directory)
input_f = os.path.abspath(args.input_file)
date = extract_date_from_filename(input_f)

df:pl.LazyFrame = pl.scan_csv(input_f, separator='\t')

df = df.filter(~pl.col("Organism Name").str.contains("Salmonella"))


# Create a new table with the new column using .mutate()
df: pl.LazyFrame = df.with_columns(pl.col("Organism Name")
    .str.replace_all("aff.", "", literal=True)
    .str.replace_all("cf.", "", literal=True)
    .str.replace_all("Candidatus ", "", literal=True)
    .str.replace_all("candidate division ", "", literal=True)
    .str.replace_all("[^a-zA-Z0-9\\s]", "", literal=False) # Note: double backslash for regex in Python string
    .str.extract("^\\s*(\\S+)", 1)
    .alias("genus")
)



df2: pl.DataFrame = df.collect()
print(
    f"Beginning to separate {df2.n_unique('genus')} genera, this will take a while..."
)
groups = df2.group_by("genus")
groups.map_groups(process_and_save_group)
print("Finished separating genera, files saved in:", output_d)
