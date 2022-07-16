#!/usr/bin/env python3

"""
Script used to convert binaries into `memreadh` compatible memory dumps.
"""

from sys import argv
import random

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("binfile",
                        help="binfile to generate hex")
    parser.add_argument("--memsize", type=int, default=0,
                        help="number of memory words")
    parser.add_argument("--scrkey", type=int, default=0,
                        help="key for address scrambling")
    parser.add_argument("--enckey", type=int, default=0,
                        help="key for data encryption")
    parser.add_argument("--use-scr", action='store_true',
                        help="key for data encryption")
    args = parser.parse_args()

    with open(args.binfile, "rb") as f:
        bindata = f.read()

    assert(len(bindata) % 4 == 0)

    size = len(bindata)/4
    if size > args.memsize:
        print(f'Memory is too small: {size} > {args.memsize})')
        exit(1)

    words = []
    for i in range(args.memsize):
        if i < len(bindata) // 4:
            w = bindata[4*i : 4*i+4]
            words.append((w[3] << 24) | (w[2] << 16) | (w[1] << 8) | w[0])
        else:
            words.append(0)

    mem = {}
    for addr, word in enumerate(words):
        word      = word ^ args.enckey
        addr      = (addr << 2) ^ args.scrkey if args.use_scr else (addr << 2)
        mem[addr] = word ^ addr if args.use_scr else word

    for addr in sorted(mem):
        print(f'{mem[addr]:08x}')

