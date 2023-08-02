#!/bin/python

'''
> cat table/smyh_map.txt | ./asset/gen_mappings_table.py
'''

import sys

# {"Q": ["食Qd", "户Qh", ...], "W": [...]}
mappings: dict[str, list[str]] = {}

def get_row_data(key, line, cols) -> str:
    '''
    generate a row of data from mappings of key
    '''
    if line == 0:
        # head line
        return "="*8 + " "*3 + key + " "*3 + "="*8 + "\t"
    comps = mappings[key]
    if line*cols <= len(comps):
        # a\tb\tc\t
        return "\t".join(comps[(line-1)*cols:line*cols]) + "\t"
    elif line*cols < len(comps):
        # a\tb\t\t
        return "\t".join(comps[(line-1)*cols:len(comps)]) + "\t"*(line*cols-len(comps))
    else:
        # \t\t\t
        return "\t"*cols

# read all mappings from stdin
for line in sys.stdin.readlines():
    code, comp = line.strip().split('\t')[:2]
    key = code[0]
    comp = comp.strip("{}")
    if not mappings.get(key):
        mappings[key] = []
    # │食   Qd│戶   Qh│户   Qh│
    mappings[key].append(comp + " "*(5-len(comp)*2) + code)

for row in ["QWERT", "YUIOP", "ASDFG", "HJKL", "ZXCVB", "NM"]:
    # suppose that every table has 10 rows, then filter the empty ones
    for i in range(0, 10):
        line = []
        for key in row:
            line.append(get_row_data(key, i, 3))
        line = "\t".join(line).rstrip("\t")
        if len(line) != 0:
            print("\t", line, "\t", sep="")
    print()

print("\tvim:\tts=8\tlcs=tab\\:\\ \\ \\│\t")
