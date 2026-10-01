#!/usr/bin/env bash
# guard-scope: a scope may be built only if a human has approved it.
#
# Checks the scope file's front matter:
#   - status is exactly "approved"
#   - approved_by and approved_on are present; approved_on is a real date, not in the future
#   - id matches the file name
#   - target_org is listed in config/allowed-orgs.json
#   - metadata_types is non-empty and a subset of config/metadata-allowlist.json
#
# Exit 0 only when every check passes. Prints every failure, not just the first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCOPE="${1:?usage: guard-scope.sh scopes/REQ-xxx.md}"
ALLOWLIST="${METADATA_ALLOWLIST:-$ROOT/config/metadata-allowlist.json}"
ORGS="${ALLOWED_ORGS:-$ROOT/config/allowed-orgs.json}"

python3 - "$SCOPE" "$ALLOWLIST" "$ORGS" "$ROOT" <<'PY'
import datetime as dt, json, os, re, sys
scope, allowlist_path, orgs_path, root = sys.argv[1:5]
sys.path.insert(0, os.path.join(root, "scripts", "lib"))
from frontmatter import read

if not os.path.isfile(scope):
    print(f"✘ scope file not found: {scope}"); sys.exit(1)
meta, _ = read(scope)
allowed_types = set(json.load(open(allowlist_path))["allowed"])
allowed_orgs = {o["alias"] for o in json.load(open(orgs_path))["orgs"]}
problems = []

if meta.get("status") != "approved":
    problems.append(f"status is '{meta.get('status', '')}', must be 'approved' (a human sets this)")
if not meta.get("approved_by"):
    problems.append("approved_by is empty")
when = meta.get("approved_on", "")
try:
    d = dt.date.fromisoformat(when)
    if d > dt.date.today():
        problems.append(f"approved_on {when} is in the future")
except ValueError:
    problems.append(f"approved_on '{when}' is not an ISO date (YYYY-MM-DD)")
expected_id = re.sub(r"\.md$", "", os.path.basename(scope))
if meta.get("id") != expected_id:
    problems.append(f"id '{meta.get('id', '')}' does not match file name '{expected_id}'")
if meta.get("target_org") not in allowed_orgs:
    problems.append(f"target_org '{meta.get('target_org', '')}' is not in config/allowed-orgs.json ({sorted(allowed_orgs)})")
types = meta.get("metadata_types", [])
if isinstance(types, str):
    types = [types] if types else []
if not types:
    problems.append("metadata_types is empty; a scope must declare what it will touch")
for t in types:
    if t not in allowed_types:
        problems.append(f"metadata type '{t}' is not in config/metadata-allowlist.json")

if problems:
    print(f"✘ guard-scope: {scope} is NOT buildable")
    for p in problems:
        print(f"   - {p}")
    sys.exit(1)
print(f"✔ guard-scope: {scope} approved by {meta['approved_by']} on {when}; may touch {', '.join(types)}")
PY
