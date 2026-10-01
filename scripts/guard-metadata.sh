#!/usr/bin/env bash
# guard-metadata: the changed metadata must be (a) in the global allowlist and
# (b) declared in the scope's metadata_types. Deletions and destructive manifests are refused.
#
# usage: guard-metadata.sh <base-ref> scopes/REQ-xxx.md
# Compares <base-ref>...HEAD (merge-base diff), so it works on a PR merge commit in CI
# and on a local branch alike.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:?usage: guard-metadata.sh <base-ref> <scope-file>}"
SCOPE="${2:?usage: guard-metadata.sh <base-ref> <scope-file>}"
ALLOWLIST="${METADATA_ALLOWLIST:-$ROOT/config/metadata-allowlist.json}"

cd "$ROOT"
CHANGES="$(git diff --no-renames --name-status "$BASE...HEAD" -- force-app manifest 2>/dev/null || git diff --no-renames --name-status "$BASE" -- force-app manifest)"
ALL_CHANGED="$(git diff --name-only "$BASE...HEAD" 2>/dev/null || git diff --name-only "$BASE")"

python3 - "$SCOPE" "$ALLOWLIST" "$ROOT" "$CHANGES" "$ALL_CHANGED" <<'PY'
import json, os, re, sys
scope, allowlist_path, root, changes, all_changed = sys.argv[1:6]
sys.path.insert(0, os.path.join(root, "scripts", "lib"))
from frontmatter import read

allowed = set(json.load(open(allowlist_path))["allowed"])
meta, _ = read(scope)
declared = meta.get("metadata_types", [])
declared = set([declared] if isinstance(declared, str) else declared)

RULES = [
    (r"^force-app/.*/objects/[^/]+/fields/[^/]+\.field-meta\.xml$", "CustomField"),
    (r"^force-app/.*/objects/[^/]+/validationRules/.*\.validationRule-meta\.xml$", "ValidationRule"),
    (r"^force-app/.*/objects/[^/]+/listViews/.*\.listView-meta\.xml$", "ListView"),
    (r"^force-app/.*/objects/[^/]+/recordTypes/.*\.recordType-meta\.xml$", "RecordType"),
    (r"^force-app/.*/objects/([^/]+)/\1\.object-meta\.xml$", "CustomObject"),
    (r"^force-app/.*/globalValueSets/.*\.globalValueSet-meta\.xml$", "GlobalValueSet"),
    (r"^force-app/.*/permissionsets/.*\.permissionset-meta\.xml$", "PermissionSet"),
    (r"^force-app/.*/layouts/.*\.layout-meta\.xml$", "Layout"),
    (r"^force-app/.*/flexipages/.*\.flexipage-meta\.xml$", "FlexiPage"),
    (r"^force-app/.*/flows/.*\.flow-meta\.xml$", "Flow"),
    (r"^force-app/.*/classes/", "ApexClass"),
    (r"^force-app/.*/triggers/", "ApexTrigger"),
    (r"^force-app/.*/profiles/", "Profile"),
    (r"^force-app/.*/settings/", "Settings"),
    (r"^force-app/.*/lwc/", "LightningComponentBundle"),
    (r"^force-app/.*/aura/", "AuraDefinitionBundle"),
    (r"^force-app/.*/standardValueSets/", "StandardValueSet"),
    (r"^force-app/.*/permissionsetgroups/", "PermissionSetGroup"),
    (r"^force-app/.*/sharingRules/", "SharingRules"),
    (r"^force-app/.*/connectedApps/", "ConnectedApp"),
    (r"^force-app/.*/namedCredentials/", "NamedCredential"),
    (r"^force-app/.*/remoteSiteSettings/", "RemoteSiteSetting"),
]

def classify(path):
    for pattern, mdtype in RULES:
        if re.search(pattern, path):
            return mdtype
    return "Unknown"

problems, rows = [], []
for p in all_changed.split("\n"):
    if re.search(r"destructive", p, re.I) or p.startswith("manifest/"):
        problems.append(f"{p}: destructive manifests are never allowed")

for line in [l for l in changes.split("\n") if l.strip()]:
    status, path = line.split("\t", 1)
    path = path.split("\t")[-1]  # renames: take the new path
    mdtype = classify(path)
    rows.append((status, mdtype, path))
    if status.startswith("D"):
        problems.append(f"{path}: deletion. This pipeline never deletes metadata.")
    if mdtype == "Unknown":
        problems.append(f"{path}: unrecognised metadata location; refusing rather than guessing")
    elif mdtype not in allowed:
        problems.append(f"{path}: type {mdtype} is not in config/metadata-allowlist.json")
    elif mdtype not in declared:
        problems.append(f"{path}: type {mdtype} is not declared in the scope's metadata_types {sorted(declared)}")

if not rows:
    problems.append("no metadata changed under force-app/; a build PR must change metadata")

for status, mdtype, path in rows:
    print(f"   {status:2} {mdtype:16} {path}")
if problems:
    print(f"✘ guard-metadata: changes exceed the scope {meta.get('id','?')}")
    for p in problems:
        print(f"   - {p}")
    sys.exit(1)
print(f"✔ guard-metadata: {len(rows)} file(s), all within scope {meta.get('id')} ({', '.join(sorted(declared))})")
PY
