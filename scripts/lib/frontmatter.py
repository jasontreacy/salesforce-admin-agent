#!/usr/bin/env python3
"""Minimal front-matter reader shared by the guard scripts.

Supports `key: value` and `key: [a, b, c]`. Deliberately not full YAML: no
dependency to install on a CI runner, and no surprises from anchors or
multi-line scalars. A scope that needs more than this is too clever.

Usage:
  frontmatter.py FILE            -> JSON of all keys
  frontmatter.py FILE KEY        -> value (lists joined by spaces)
"""
import json
import sys


def read(path):
    text = open(path, encoding="utf-8").read()
    if not text.startswith("---\n"):
        raise SystemExit(f"{path}: no front matter (file must start with ---)")
    end = text.find("\n---", 4)
    if end < 0:
        raise SystemExit(f"{path}: unterminated front matter")
    data = {}
    for raw in text[4:end].splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            raise SystemExit(f"{path}: bad front-matter line: {raw!r}")
        key, value = line.split(":", 1)
        key, value = key.strip(), value.strip()
        if value.startswith("[") and value.endswith("]"):
            data[key] = [v.strip().strip("\"'") for v in value[1:-1].split(",") if v.strip()]
        else:
            data[key] = value.strip("\"'")
    return data, text[end + 4:]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    meta, _ = read(sys.argv[1])
    if len(sys.argv) > 2:
        value = meta.get(sys.argv[2], "")
        print(" ".join(value) if isinstance(value, list) else value)
    else:
        print(json.dumps(meta, indent=2))
