#!/usr/bin/env bash
# validate: the ONLY sanctioned way this repo talks to an org with deploy semantics.
#
# Runs guard-org, then a check-only deploy (`--dry-run`) of force-app against the org,
# then asserts from the API response that the deployment really was checkOnly.
# Nothing is saved to the org. Exit 0 only on a clean validation.
#
# Why `deploy start --dry-run` and not `deploy validate`? The latter hard-codes a minimum
# test level of RunLocalTests, which requires 75% org-wide Apex coverage. This agent
# writes no Apex (see config/metadata-allowlist.json), so TEST_LEVEL defaults to NoTestRun.
# Set TEST_LEVEL=RunLocalTests the day Apex is admitted to the allowlist.
#
# usage: validate.sh <alias> [out.json]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALIAS="${1:?usage: validate.sh <alias> [out.json]}"
OUT="${2:-$ROOT/validate-result.json}"
TEST_LEVEL="${TEST_LEVEL:-NoTestRun}"

"$ROOT/scripts/guard-org.sh" "$ALIAS"

set +e
sf project deploy start -o "$ALIAS" --dry-run --source-dir "$ROOT/force-app" \
  --test-level "$TEST_LEVEL" --wait 30 --json > "$OUT"
SF_EXIT=$?
set -e

python3 - "$OUT" "$SF_EXIT" <<'PY'
import json, sys
out, sf_exit = sys.argv[1], int(sys.argv[2])
d = json.load(open(out)); r = d.get("result") or {}
check_only = r.get("checkOnly")
status = r.get("status")
if check_only is not True:
    print(f"✘ validate: deployment {r.get('id')} was NOT check-only (checkOnly={check_only}). Investigate before anything else.")
    sys.exit(2)
fails = (r.get("details") or {}).get("componentFailures") or []
if isinstance(fails, dict): fails = [fails]
if status != "Succeeded" or sf_exit != 0:
    print(f"✘ validate: {status} (exit {sf_exit}) — {d.get('message','')}")
    for f in fails:
        print(f"   - {f.get('componentType')} {f.get('fullName')}: {f.get('problem')}")
    sys.exit(1)
print(f"✔ validate: check-only deploy {r.get('id')} Succeeded — "
      f"{r.get('numberComponentsDeployed')}/{r.get('numberComponentsTotal')} components, "
      f"tests {r.get('numberTestsCompleted',0)}/{r.get('numberTestsTotal',0)}, checkOnly=True")
PY
