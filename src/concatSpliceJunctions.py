# concatSpliceJunctions.py

import sys
import os
import pandas as pd

sj_files = sys.argv[1:]

def read_splice_junc_table(file):
    return pd.read_csv(file, sep='\t', header=None)

def join_splice_junc_table(tables, min_samples: int, no_private: bool=True):
    joined_table = pd.concat(tables, axis=0)

    start_end_sj = joined_table
