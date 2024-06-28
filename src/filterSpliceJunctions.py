# filterSpliceJunctions.py

import sys
import os
import pandas as pd

sj_tab_file = sys.argv[1]

def to_string(df):
    for _, row in df.iterrows():
        row_string = '\t'.join(row.astype(str).to_list())
        print(row_string)

def main():
    assert os.path.exists(sj_tab_file), "ERROR: No such *SJ.out.tab file"

    sj_tab = pd.read_csv(sj_tab_file, sep='\t', header=None)

    # Filter out the junctions on chrM
    junctions_chr_m = sj_tab.iloc[:, 0].apply(lambda chr: chr.lower() == 'chrm' or \
                                                          chr.lower() == 'm')

    # Filter out non-canonical junctions (column5 == 0)
    junctions_non_canonical = sj_tab.iloc[:, 4].apply(lambda x: x == 0)

    # Filter out junctions supported by too few uniquely mapping reads (column7 <= n)
    junctions_low_support = sj_tab.iloc[:, 6].apply(lambda x: x == 0)

    filtered_sj_tab = sj_tab[~junctions_chr_m & \
                             ~junctions_non_canonical & \
                             ~junctions_low_support]

    to_string(filtered_sj_tab)
    #print(filtered_sj_tab.to_string(header=None, index=False))
    #print(f'{len(sj_tab) - len(filtered_sj_tab)} junctions removed, '
    #      f'{len(filtered_sj_tab)} are remaining after filtering.')

if __name__ == '__main__':
    main()
