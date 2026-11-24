#!/usr/bin/env python3
"""Create a deterministic, uniformly sampled mobile Gaussian PLY derivative.

The source file is never modified. The output keeps the original vertex record
format and every vertex property, changing only the vertex count and which
complete records are retained.
"""
from __future__ import annotations

import argparse
import random
import re
import struct
import sys
from pathlib import Path

PLY_TYPES = {
    "char": "b", "int8": "b",
    "uchar": "B", "uint8": "B",
    "short": "h", "int16": "h",
    "ushort": "H", "uint16": "H",
    "int": "i", "int32": "i",
    "uint": "I", "uint32": "I",
    "float": "f", "float32": "f",
    "double": "d", "float64": "d",
}


def read_header(stream):
    lines = []
    while True:
        line = stream.readline()
        if not line:
            raise ValueError("PLY header ended before end_header.")
        lines.append(line)
        if line.strip() == b"end_header":
            break

    header = b"".join(lines)
    if not re.search(rb"(?m)^format binary_little_endian 1\.0\s*$", header):
        raise ValueError("Expected binary_little_endian PLY format.")

    elements = []
    current = None
    for raw in lines:
        parts = raw.decode("ascii", "strict").strip().split()
        if not parts:
            continue
        if parts[0] == "element":
            if len(parts) != 3:
                raise ValueError("Malformed element declaration: " + raw.decode(errors="replace").strip())
            current = {"name": parts[1], "count": int(parts[2]), "properties": []}
            elements.append(current)
        elif parts[0] == "property" and current is not None:
            if len(parts) == 3 and parts[1] in PLY_TYPES:
                current["properties"].append((parts[2], PLY_TYPES[parts[1]]))
            elif len(parts) >= 2 and parts[1] == "list":
                if current["name"] == "vertex":
                    raise ValueError("List properties in vertex records are not supported.")
                current["properties"].append(("__list__", None))
            else:
                raise ValueError("Unsupported PLY property declaration: " + " ".join(parts))

    vertex_elements = [e for e in elements if e["name"] == "vertex"]
    if len(vertex_elements) != 1:
        raise ValueError("Expected exactly one vertex element.")
    vertex = vertex_elements[0]
    if not vertex["properties"] or any(code is None for _, code in vertex["properties"]):
        raise ValueError("Could not determine fixed-size scalar vertex records.")
    if elements.index(vertex) != 0:
        raise ValueError("Vertex must be the first PLY element for safe streaming reduction.")

    record_format = "<" + "".join(code for _, code in vertex["properties"])
    return header, vertex["count"], struct.calcsize(record_format)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Original binary PLY (kept untouched)")
    parser.add_argument("--target", type=int, default=750000, help="Target vertex count (default: 750000)")
    parser.add_argument("--seed", type=int, default=750000, help="Sampling seed for repeatable output")
    parser.add_argument("--output", type=Path, help="Output path (default: INPUT_750k.ply)")
    args = parser.parse_args()

    source = args.input
    if not source.is_file():
        parser.error(f"Input file does not exist: {source}")
    if args.target < 1:
        parser.error("--target must be at least 1")

    destination = args.output or source.with_name(source.stem + "_750k.ply")
    if source.resolve() == destination.resolve():
        parser.error("Output must be a different file; the original is protected.")

    with source.open("rb") as src:
        header, vertex_count, record_size = read_header(src)
        if args.target >= vertex_count:
            parser.error(f"Target ({args.target:,}) must be smaller than source ({vertex_count:,}).")

        # Sampling indices rather than decoding/re-encoding properties preserves
        # every retained Gaussian's exact original binary values.
        chosen = sorted(random.Random(args.seed).sample(range(vertex_count), args.target))
        new_header, replacements = re.subn(
            rb"(?m)^(element vertex )\d+(\s*)$",
            lambda match: match.group(1) + str(args.target).encode("ascii") + match.group(2),
            header,
            count=1,
        )
        if replacements != 1:
            raise ValueError("Could not safely update the vertex count in the PLY header.")

        temp = destination.with_suffix(destination.suffix + ".tmp")
        try:
            with temp.open("wb") as out:
                out.write(new_header)
                selected_cursor = 0
                for index in range(vertex_count):
                    record = src.read(record_size)
                    if len(record) != record_size:
                        raise ValueError(f"Unexpected end of file at vertex {index:,}.")
                    if selected_cursor < len(chosen) and index == chosen[selected_cursor]:
                        out.write(record)
                        selected_cursor += 1
                    if index and index % 250000 == 0:
                        print(f"Scanned {index:,}/{vertex_count:,} vertices; kept {selected_cursor:,}.")
                # Preserve any non-vertex elements or trailing payload unchanged.
                while True:
                    chunk = src.read(1024 * 1024)
                    if not chunk:
                        break
                    out.write(chunk)
            temp.replace(destination)
        except Exception:
            temp.unlink(missing_ok=True)
            raise

    print(f"Created: {destination}")
    print(f"Vertices: {vertex_count:,} -> {args.target:,} ({100 * args.target / vertex_count:.1f}% retained)")
    print(f"Vertex record size: {record_size} bytes")
    print("Original source was not changed.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
