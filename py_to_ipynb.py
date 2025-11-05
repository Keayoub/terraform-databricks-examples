#!/usr/bin/env python3
"""
py_to_ipynb.py

Convert a .py file (with optional # %% cell markers) into a Jupyter .ipynb file.

Usage:
    python py_to_ipynb.py path/to/script.py [--outdir path/to/output_dir]
    python py_to_ipynb.py path/to/folder  # converts all .py files inside (non-recursive)

Features:
 - Recognizes cell separators: lines starting with '# %%' or '#%%'
 - Preserves code cells and basic markdown cells when a cell starts with '# %% [markdown]' or '# %% markdown'
 - Produces notebooks compatible with nbformat v4

This is lightweight and doesn't require heavy dependencies. It will try to import nbformat if available
to produce a proper .ipynb file; otherwise it will write a minimal JSON structure.
"""

from __future__ import annotations

import argparse
import json
import uuid
import os
import sys
from typing import List, Tuple


def split_into_cells(lines: List[str]) -> List[Tuple[str, List[str]]]:
    """Split python source lines into cells.

    Returns a list of tuples: (cell_type, cell_lines)
    cell_type is 'code' or 'markdown'.
    A cell marker is a line that starts with '# %%' or '#%%'. If it contains 'markdown' it's a markdown cell.
    """
    cells: List[Tuple[str, List[str]]] = []
    cur_type = 'code'
    cur_lines: List[str] = []

    # helper to decide markdown for a MAGIC line
    def magic_is_markdown(text: str) -> bool:
        t = text.lstrip()
        if not t:
            return False
        # explicit Databricks markdown directive
        if t.startswith('%md') or t.startswith('%md-'):
            return True
        # HTML blocks are exported as # MAGIC <div>... etc.
        if t.startswith('<') or t.startswith('&'):
            return True
        # Markdown tables/headers (|, ##) are common
        if t.startswith('|') or t.startswith('##') or t.startswith('# '):
            return True
        return False

    def flush():
        nonlocal cur_lines, cur_type
        # only append if there's any non-whitespace content
        if any((ln.strip() for ln in cur_lines)):
            cells.append((cur_type, cur_lines))
        cur_lines = []

    for raw in lines:
        line = raw.rstrip('\n')
        stripped = line.lstrip()

        # Databricks exported notebook separators
        # ignore header line
        if stripped.startswith('# Databricks notebook source'):
            continue

        if stripped.startswith('# COMMAND'):
            flush()
            cur_type = 'code'
            continue

        # DBTITLE lines often annotate the next cell; convert to a small markdown header
        if stripped.startswith('# DBTITLE'):
            # extract anything after the comma or the title text
            # we'll add as a markdown line
            parts = line.split(',', 1)
            title = parts[1].strip() if len(parts) > 1 else ''
            # start a markdown cell with the title
            flush()
            cur_type = 'markdown'
            if title:
                # remove leading # if present
                if title.startswith('#'):
                    title = title.lstrip('#').strip()
                cur_lines.append(title)
            continue

        # MAGIC lines (Databricks cell magics / markdown)
        if stripped.startswith('# MAGIC'):
            # everything after '# MAGIC' is the content
            content = line.split('# MAGIC', 1)[1]
            content = content.lstrip()
            # decide if markdown directive present
            if magic_is_markdown(content):
                # remove leading %md or %md-sandbox token
                tokens = content.split(None, 1)
                if tokens and tokens[0].startswith('%md'):
                    remainder = tokens[1] if len(tokens) > 1 else ''
                else:
                    remainder = content
                if cur_type != 'markdown':
                    flush()
                    cur_type = 'markdown'
                # add remainder as markdown line (can be empty for a pure marker)
                if remainder is not None:
                    cur_lines.append(remainder)
            else:
                # If we're already in a markdown cell (previously triggered by %md),
                # treat subsequent MAGIC lines as markdown content (this is how
                # Databricks exports html/markdown blocks: first line is `%md*`,
                # following lines are `# MAGIC <html>`)
                if cur_type == 'markdown':
                    cur_lines.append(content)
                else:
                    # treat as code-like cell content (may include %sql or other magics)
                    if cur_type != 'code':
                        flush()
                        cur_type = 'code'
                    cur_lines.append(content)
            continue

        # legacy cell marker used by many tools
        if stripped.startswith('#%%') or stripped.startswith('# %%'):
            lower = stripped[3:].strip().lower()
            is_md = 'markdown' in lower
            flush()
            cur_type = 'markdown' if is_md else 'code'
            continue

        # If current cell is markdown and line starts with '# ' remove the leading '#'
        if cur_type == 'markdown':
            if stripped.startswith('#'):
                idx = line.find('#')
                after = line[idx+1:]
                if after.startswith(' '):
                    after = after[1:]
                cur_lines.append(after)
            else:
                cur_lines.append(line)
        else:
            cur_lines.append(line)

    # final flush
    if cur_lines:
        cells.append((cur_type, cur_lines))

    # remove any leading empty initial cell created by flush rules
    if cells and not any(l.strip() for l in cells[0][1]):
        cells = cells[1:]

    return cells


def make_notebook(cells: List[Tuple[str, List[str]]]) -> dict:
    """Create nbformat v4 compatible notebook dict from cells."""
    nb_cells = []
    for ctype, lines in cells:
        # strip leading/trailing empty lines
        while lines and not any(ch.strip() for ch in lines[0:1]):
            lines = lines[1:]
        while lines and not any(ch.strip() for ch in lines[-1:]):
            lines = lines[:-1]
        if not lines:
            continue

        # produce source as a list of strings (each ending with a newline)
        src_lines = [l + '\n' for l in lines]

        cell_meta = {'language': 'markdown' if ctype == 'markdown' else 'python'}
        # generate a short unique id for metadata.id
        cell_id = uuid.uuid4().hex[:8]

        if ctype == 'markdown':
            nb_cells.append({
                'cell_type': 'markdown',
                'metadata': {'language': 'markdown', 'id': cell_id},
                'source': src_lines,
            })
        else:
            nb_cells.append({
                'cell_type': 'code',
                'metadata': {'language': 'python', 'id': cell_id},
                'execution_count': None,
                'outputs': [],
                'source': src_lines,
            })

    nb = {
        'cells': nb_cells,
        'metadata': {
            'kernelspec': {
                'name': 'python3',
                'language': 'python',
                'display_name': 'Python 3'
            },
            'language_info': {
                'name': 'python'
            }
        },
        'nbformat': 4,
        'nbformat_minor': 5,
    }
    return nb


def write_ipynb(nb: dict, out_path: str) -> None:
    try:
        import nbformat

        nbobj = nbformat.from_dict(nb)
        with open(out_path, 'w', encoding='utf-8') as f:
            nbformat.write(nbobj, f)
    except Exception:
        # fallback to simple json dump
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(nb, f, ensure_ascii=False, indent=2)


def convert_file(py_path: str, out_dir: str | None = None) -> str:
    if not py_path.lower().endswith('.py'):
        raise ValueError('Input file must be a .py file')

    with open(py_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    cells = split_into_cells(lines)

    nb = make_notebook(cells)

    base = os.path.splitext(os.path.basename(py_path))[0]
    out_name = base + '.ipynb'
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, out_name)
    else:
        out_path = os.path.join(os.path.dirname(py_path), out_name)

    write_ipynb(nb, out_path)
    return out_path


def find_py_files(folder: str) -> List[str]:
    results = []
    for name in os.listdir(folder):
        if name.startswith('.'):
            continue
        full = os.path.join(folder, name)
        if os.path.isfile(full) and full.lower().endswith('.py'):
            results.append(full)
    return results


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description='Convert .py files to .ipynb (supports # %% cell markers)')
    parser.add_argument('path', help='A .py file or a folder containing .py files')
    parser.add_argument('--outdir', '-o', help='Optional output directory for .ipynb files')
    parser.add_argument('--recursive', '-r', action='store_true', help='Recursively convert .py files in subfolders')
    args = parser.parse_args(argv)

    path = args.path
    outdir = args.outdir

    targets: List[str] = []
    if os.path.isdir(path):
        if args.recursive:
            for root, _, files in os.walk(path):
                for f in files:
                    if f.lower().endswith('.py'):
                        targets.append(os.path.join(root, f))
        else:
            targets = find_py_files(path)
    elif os.path.isfile(path):
        targets = [path]
    else:
        print(f'Path not found: {path}', file=sys.stderr)
        return 2

    if not targets:
        print('No .py files found to convert.', file=sys.stderr)
        return 1

    # If no outdir provided, create a 'notebooks' folder next to the input path
    if not outdir:
        if os.path.isdir(path):
            outdir = os.path.join(path, 'notebooks')
        else:
            parent = os.path.dirname(path) or '.'
            outdir = os.path.join(parent, 'notebooks')
        try:
            os.makedirs(outdir, exist_ok=True)
        except Exception as e:
            print(f'Unable to create notebooks folder {outdir}: {e}', file=sys.stderr)
            return 2

    out_paths = []
    for t in targets:
        try:
            out_path = convert_file(t, outdir)
            print(f'Converted: {t} -> {out_path}')
            out_paths.append(out_path)
        except Exception as e:
            print(f'Failed to convert {t}: {e}', file=sys.stderr)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
