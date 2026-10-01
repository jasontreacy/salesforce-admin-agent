#!/usr/bin/env bash
# guard-org: refuse to talk to any org that is not an allowlisted non-production org.
#
# Two independent checks against the LIVE org, not the alias name:
#   1. The org id returned by `sf org display` is in config/allowed-orgs.json.
#   2. The Organization record says IsSandbox=true OR OrganizationType='Developer Edition'.
# A production org fails both. An allowlisted org that was somehow promoted fails the second.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALIAS="${1:?usage: guard-org.sh <alias>}"
ORGS="${ALLOWED_ORGS:-$ROOT/config/allowed-orgs.json}"

ORG_ID="$(sf org display -o "$ALIAS" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["id"])')"
ROW="$(sf data query -o "$ALIAS" -q "SELECT Id, OrganizationType, IsSandbox FROM Organization" --json)"

python3 - "$ALIAS" "$ORG_ID" "$ORGS" "$ROW" <<'PY'
import json, sys
alias, org_id, orgs_path, row_json = sys.argv[1:5]
allowed = {o["org_id"]: o for o in json.load(open(orgs_path))["orgs"]}
rec = json.loads(row_json)["result"]["records"][0]
live_id, org_type, is_sandbox = rec["Id"], rec["OrganizationType"], rec["IsSandbox"]
problems = []
if org_id not in allowed and org_id[:15] not in {k[:15] for k in allowed}:
    problems.append(f"org id {org_id} (alias '{alias}') is not in config/allowed-orgs.json")
if live_id[:15] != org_id[:15]:
    problems.append(f"alias resolved to {org_id} but the org reports {live_id}")
if not (is_sandbox or org_type == "Developer Edition"):
    problems.append(f"org is '{org_type}', IsSandbox={is_sandbox}. This looks like production. Refusing.")
if problems:
    print(f"✘ guard-org: REFUSING to use org '{alias}'")
    for p in problems:
        print(f"   - {p}")
    sys.exit(1)
entry = allowed.get(org_id) or next(v for k, v in allowed.items() if k[:15] == org_id[:15])
print(f"✔ guard-org: '{alias}' is {live_id} ({org_type}, IsSandbox={is_sandbox}) — {entry['client']}")
PY
