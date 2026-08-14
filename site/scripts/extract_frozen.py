#!/usr/bin/env python3
"""Verify curated frozen extracts against the committed snapshot.

Does not copy experiment dumps. If on-disk frozen result trees are absent
(typical on origin/main), this job still exists and verifies the committed
snapshot hashes.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "src" / "data"
SNAPSHOT = DATA / "SNAPSHOT.sha256"
SKIP = {"SNAPSHOT.sha256"}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def listed_json() -> list[Path]:
    files = [p for p in sorted(DATA.glob("*.json")) if p.name not in SKIP]
    return files


def write_snapshot(files: list[Path]) -> None:
    lines = ["# Frozen extract hashes. CI fails on drift.\n"]
    for path in files:
        lines.append(f"{sha256_file(path)}  {path.name}\n")
    SNAPSHOT.write_text("".join(lines), encoding="utf-8")


def read_snapshot() -> dict[str, str]:
    out: dict[str, str] = {}
    if not SNAPSHOT.exists():
        raise SystemExit("SNAPSHOT.sha256 missing")
    for line in SNAPSHOT.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        digest, name = line.split()
        out[name] = digest
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="rewrite SNAPSHOT.sha256")
    args = parser.parse_args()
    files = listed_json()
    if not files:
        raise SystemExit("no curated extracts")
    if args.write:
        write_snapshot(files)
        print("extract-hash: wrote snapshot for", len(files), "files")
        return 0
    expected = read_snapshot()
    names = {p.name for p in files}
    if names != set(expected):
        print("extract-hash FAIL: file set drift", file=sys.stderr)
        print("  have", sorted(names), file=sys.stderr)
        print("  want", sorted(expected), file=sys.stderr)
        return 1
    bad = []
    for path in files:
        got = sha256_file(path)
        if got != expected[path.name]:
            bad.append(path.name)
    if bad:
        print("extract-hash FAIL: content drift", bad, file=sys.stderr)
        return 1
    frozen_tree = ROOT.parent / "experiments" / "results"
    if frozen_tree.is_dir():
        print("extract-hash: committed snapshot OK; frozen result tree present (not copied)")
    else:
        print("extract-hash: committed snapshot OK; frozen sources absent on this branch; snapshot verification only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
