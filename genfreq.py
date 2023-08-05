#!/bin/python

import sys

freq_set: dict[str, int] = {}
total: int = 0

with open(sys.argv[1]) as file:
    for line in file.readlines():
        [char, freq] = line.strip().split('\t')[:2]
        freq = int(freq)
        freq_set[char] = freq
        total += freq

for char in freq_set:
    freq = freq_set[char] / total
    print("%s\t%.8f" % (char, freq))
