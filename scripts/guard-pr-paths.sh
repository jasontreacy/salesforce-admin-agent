#!/usr/bin/env bash
# guard-pr-paths: an agent branch may only touch the files its job is about.
#
#   build/REQ-xxx  -> force-app/** and builds/REQ-xxx.md only
#   scope/REQ-xxx  -> scopes/REQ-xxx.md only
#   anything else  -> a maintainer branch; no path restriction (CI still validates metadata)
#
# This is what stops a build PR from quietly editing its own scope, the allowlists,
# the guard scripts, the workflows or the hook. Those paths are frozen on agent branches.
#
# usage: guard-pr-paths.sh <base-ref> <branch-name>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:?usage: guard-pr-paths.sh <base-ref> <branch-name>}"
BRANCH="${2:?usage: guard-pr-paths.sh <base-ref> <branch-name>}"
cd "$ROOT"
CHANGED="$(git diff --name-only "$BASE...HEAD" 2>/dev/null || git diff --name-only "$BASE")"

python3 - "$BRANCH" "$CHANGED" <<'PY'
import re, sys
branch, changed = sys.argv[1], [p for p in sys.argv[2].split("\n") if p]
m = re.match(r"^(build|scope)/(REQ-\d+)$", branch)
if not m:
    print(f"ℹ guard-pr-paths: '{branch}' is a maintainer branch; no path restriction applied")
    sys.exit(0)
kind, req = m.groups()
if kind == "build":
    ok = lambda p: p.startswith("force-app/") or p == f"builds/{req}.md"
    allowed_desc = f"force-app/** and builds/{req}.md"
else:
    ok = lambda p: p == f"scopes/{req}.md"
    allowed_desc = f"scopes/{req}.md"
bad = [p for p in changed if not ok(p)]
if not changed:
    print(f"✘ guard-pr-paths: {branch} changes nothing"); sys.exit(1)
if bad:
    print(f"✘ guard-pr-paths: {branch} may only change {allowed_desc}. Out of bounds:")
    for p in bad:
        print(f"   - {p}")
    sys.exit(1)
print(f"✔ guard-pr-paths: {branch} touches {len(changed)} file(s), all within {allowed_desc}")
PY
