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


import matplotlib.pyplot as plt
import seaborn as sns
import polars as pl
import os

def main():
    print("Hello from plots-count-fasta!")

def plots(df:pl.DataFrame, output_name:str,extension:str, transparent:bool):
    # Configurar el estilo de los gráficos
    sns.set_style("whitegrid")

    # Columnas a graficar
    columns_to_plot = ["assembly_length", "number_of_sequences", "N50", "GC_percentage", "N_percentage"]
    titles = ["Assembly size (bp.)", "Scaffold count", "N50 (bp.)", "GC ratio (%)", "N's ratio (%)"]
    colors = ["#FF5733", "#33FF57", "#5733FF", "#FFC300", "#C70039"]

    # Crear la figura y ejes con orientación horizontal
    fig, axes = plt.subplots(nrows=len(columns_to_plot), figsize=(12, 10), sharex=False)

    # Generar los boxplots horizontales
    for i, col in enumerate(columns_to_plot):
        sns.boxplot(ax=axes[i], x=df[col], color=colors[i], width=0.5, 
                    flierprops={"marker": "o", "markerfacecolor": "black", "markeredgecolor": "black"})
        axes[i].set_title(titles[i], fontsize=14, fontweight="bold")
        axes[i].set_ylabel("")
        axes[i].set_xlabel(titles[i])

    # Ajustar el layout
    plt.tight_layout()
    plt.savefig(fname=f"{output_name}.{extension}",format=extension, transparent=transparent)

def take_input(min_len=None):
    import sys

    err_msg = f"""Usage:
    {sys.argv[0]} <input_stats_file> [output_extension] [transparent]
    input_stats_file    file path, output from count-fasta-rs
    output_extension     resulting imagen will end up with an extension of 'png', 'pdf', 'svg' [Default: 'png']
    transparent 'transparent' results in a transparent figure

    Example:
    {sys.argv[0]} ./Aphelenchoides_19-02-2025_stats1.csv
    {sys.argv[0]} ./Aphelenchoides_19-02-2025_stats1.csv pdf
    {sys.argv[0]} ./Aphelenchoides_19-02-2025_stats1.csv svg
    {sys.argv[0]} ./Aphelenchoides_19-02-2025_stats1.csv png transparent
    """
    if min_len and min_len > len(sys.argv) - 1:
        print(err_msg)
        sys.exit()
    input_stats_file =  sys.argv[1]
    if len(sys.argv) > 2:
        output_extension=sys.argv[2]
    else:
        output_extension="png"
    if len(sys.argv) > 3:
        transparent=True if sys.argv[3] == "transparent" else False
    else:
        transparent=False


    return input_stats_file,  output_extension, transparent


if __name__ == "__main__":
    input_stats, output_ext, transparent=take_input(1)
    stats_filename, ext=os.path.splitext(input_stats)
    df = pl.read_csv(source=input_stats,separator=";",low_memory=True)
    plots(df,stats_filename, output_ext, transparent)
