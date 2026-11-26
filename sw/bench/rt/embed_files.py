#!/usr/bin/env python3
"""Write a C file embedding input files for the bare-metal runtime.
Usage: embed_files.py out.c [--stdin FILE] [FILE ...]"""
import argparse, os
ap = argparse.ArgumentParser()
ap.add_argument("out"); ap.add_argument("--stdin"); ap.add_argument("files", nargs="*")
a = ap.parse_args()
files = list(a.files) + ([a.stdin] if a.stdin and a.stdin not in a.files else [])
with open(a.out, "w") as f:
    f.write('#include "bm_files.h"\n')
    for i, p in enumerate(files):
        data = open(p, "rb").read()
        f.write(f"static const unsigned char d{i}[{len(data) + 1}] = {{")
        f.write(",".join(str(b) for b in data) + (",0" if data else "0") + "};\n")
    f.write("const bm_file_t bm_files[] = {\n")
    for i, p in enumerate(files):
        f.write(f'  {{"{os.path.basename(p)}", d{i}, {os.path.getsize(p)}}},\n')
    f.write("  {0, 0, 0}\n};\n")
    if a.stdin:
        f.write(f"const bm_file_t *const bm_stdin = &bm_files[{files.index(a.stdin)}];\n")
    else:
        f.write("const bm_file_t *const bm_stdin = 0;\n")
