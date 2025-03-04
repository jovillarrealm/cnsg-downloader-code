import polars as pl
import re
import sys
import os

_, input_f, output_d = sys.argv
output_d = os.path.abspath(output_d)
input_f = os.path.abspath(input_f)


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


def extract_genus(s: str) -> str:
    duds = [
        "aff.",
        "cf.",
    ]
    dud = False
    for dud in duds:
        if dud in s:
            s = s.replace(dud, "")
            dud = True
    if "Candidatus " in s:
        s = s.replace("Candidatus ", "")
    s = re.sub(r"[^a-zA-Z0-9\s]", "", s)

    words = s.split()
    if len(words) >= 1:
        return words[0]
    else:
        return ""


date = extract_date_from_filename(input_f)
prefix = "DUD"
df = pl.read_csv(input_f, separator="\t")

df = df.filter(~pl.col("Organism Name").str.contains("Salmonella"))

result = df.with_columns(
    genus=pl.col("Organism Name").map_elements(extract_genus, return_dtype=pl.Utf8()),
)


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


print(
    f"Beginning to separate {result.n_unique('genus')} genera, this will take a while"
)
groups = result.group_by("genus")
groups.map_groups(process_and_save_group)
print(result)
