#!/usr/bin/env python3
"""Check decompressed APK entries and AOT strings for required/forbidden brand markers."""

import argparse
from pathlib import Path
import subprocess
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--require", action="append", required=True)
    parser.add_argument("--forbid", action="append", required=True)
    args = parser.parse_args()
    present = set()
    architectures = 0
    with zipfile.ZipFile(args.apk) as archive, tempfile.TemporaryDirectory() as temp:
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            data = archive.read(entry)
            for marker in args.forbid:
                if marker.encode() in data or marker.encode("utf-16le") in data:
                    raise SystemExit(f"FAIL: {marker!r} found in {entry.filename}")
            if entry.filename.endswith("/libapp.so"):
                binary = Path(temp) / f"libapp-{architectures}.so"
                binary.write_bytes(data)
                output = subprocess.check_output(
                    ["strings", "-a", str(binary)], text=True, errors="replace"
                )
                architectures += 1
                present.update(marker for marker in args.require if marker in output)
                for marker in args.forbid:
                    if marker in output:
                        raise SystemExit(f"FAIL: strings found {marker!r}")
    missing = set(args.require) - present
    if architectures == 0 or missing:
        raise SystemExit(f"FAIL: AOT positive controls missing: {sorted(missing)}")
    print(f"PASS: {args.apk.name}; {architectures} AOT architectures; "
          "own markers present and forbidden markers absent")


if __name__ == "__main__":
    main()
