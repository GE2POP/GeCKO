import os
import re
import argparse
import pandas as pd

parser = argparse.ArgumentParser(description="convert positions of the polymorphic sites on the complete genomic reference")
parser.add_argument("-v", "--vcf", dest="vcf", help="path to input vcf raw file ")
parser.add_argument("-c", "--vcf_converted", dest="vcf_converted", help="path to vcf file converted")
args = parser.parse_args()
vcf = args.vcf
vcf_converted = args.vcf_converted



flag = True
chroms = [
    ('chr1A', 609493238),
    ('chr1B', 712626289),
    ('chr2A', 788782410),
    ('chr2B', 825750385),
    ('chr3A', 767616973),
    ('chr3B', 865950040),
    ('chr4A', 751837965),
    ('chr4B', 684047826),
    ('chr5A', 715386202),
    ('chr5B', 726095352),
    ('chr6A', 633698003),
    ('chr6B', 724204431),
    ('chr7A', 747227478),
    ('chr7B', 777835607)]


with open(vcf, 'r') as f1:
    with open(vcf_converted, 'w') as f2:
        for line in f1:
            if flag and re.match('##source', line):
                flag = False
                for k, L in chroms:
                    f2.write(f'##contig=<ID={k},length={L}>\n')
            if not re.match('##contig', line): f2.write(line)
            if re.match('#CHROM', line):
                header = list(line.split("\t"))
                break
        df = pd.DataFrame(columns=header)
        i = 0
        for line in f1:
            bits = line.split()
            ch, start, end = bits[0].rsplit('_', 2)
            start = int(start)
            end = int(end)
            pos = int(start) + int(bits[1]) - 1
            bits[0] = ch
            bits[1] = str(pos)
            df.loc[i] = bits
            i = i+1
            #f2.write('\t'.join(bits) + '\n')
        df2 = df.sort_values(by=['#CHROM','POS'], ascending = (True, True))
        df2.reset_index(inplace=True, drop=True)
        for row in range(len(df2)):
            f2.write('\t'.join(df2.loc[row]))