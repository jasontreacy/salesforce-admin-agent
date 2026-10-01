#!/usr/bin/env bash
# PreToolUse hook for the Bash tool. Reads the tool call as JSON on stdin and exits 2
# (block, with the reason fed back to the agent) when the command would:
#   - deploy for real (`sf project deploy start` without --dry-run, `deploy quick`, `deploy resume`)
#   - write records or run anonymous Apex
#   - create, delete or log in to orgs
#   - merge or review a PR, change secrets, delete the repo, or mutate GitHub via raw API calls
#   - push to main, force-push, or push from a branch that is not build/REQ-* or scope/REQ-*
#   - run an sf command against an org that is not in config/allowed-orgs.json, or with no explicit org
#
# This is the agent-side layer. It is not the only layer: CI and GitHub branch protection
# enforce the same rules without trusting this process. See docs/DESIGN.md.
set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
INPUT="$(cat)"   # the tool call JSON; read it before the heredoc below takes over stdin
python3 - "$ROOT" "$INPUT" <<'PY'
import json, os, re, subprocess, sys
root = sys.argv[1]
try:
    data = json.loads(sys.argv[2])
except json.JSONDecodeError:
    sys.exit(0)
if data.get("tool_name") != "Bash":
    sys.exit(0)
cmd = (data.get("tool_input") or {}).get("command", "")
orgs = json.load(open(os.path.join(root, "config", "allowed-orgs.json")))["orgs"]
allowed_aliases = {o["alias"] for o in orgs} | {o["org_id"] for o in orgs}

def deny(reason):
    print(f"BLOCKED by .claude/hooks/guard-commands.sh — {reason}", file=sys.stderr)
    sys.exit(2)

for seg in re.split(r"\s*(?:&&|\|\||;|\|)\s*", cmd):
    s = seg.strip()
    if re.search(r"\bsf\s+project\s+deploy\s+start\b", s) and "--dry-run" not in s:
        deny("`sf project deploy start` is only allowed with --dry-run. Real deploys run in CI after a human approves the environment.")
    if re.search(r"\bsf\s+project\s+deploy\s+(quick|resume)\b", s):
        deny("`sf project deploy quick/resume` can complete a real deployment.")
    if re.search(r"\bsf\s+data\s+(create|update|delete|upsert|import|bulk)\b", s) or re.search(r"\bsf\s+data\s+tree\s+import\b", s):
        deny("the agent never writes, imports or deletes records.")
    if re.search(r"\bsf\s+apex\s+run\b", s):
        deny("anonymous Apex can change anything in an org.")
    if re.search(r"\bsf\s+org\s+(delete|create|login)\b", s):
        deny("the agent does not create, delete or authenticate orgs.")
    if re.search(r"\bsf\s+project\s+delete\b", s):
        deny("nothing is deleted by this pipeline.")
    if re.search(r"\bgh\s+pr\s+(merge|review)\b", s):
        deny("merging and reviewing are human actions.")
    if re.search(r"\bgh\s+(repo\s+delete|secret|auth)\b", s):
        deny("repository secrets, auth and deletion are operator actions.")
    if re.search(r"\bgh\s+api\b", s) and re.search(r"(?:-X|--method)\s+(?:PUT|PATCH|DELETE|POST)\b", s):
        deny("mutating GitHub through raw API calls is not allowed; use the sanctioned gh subcommands.")
    if re.search(r"\bgit\s+push\b", s):
        if re.search(r"(--force|--force-with-lease|\s-f\b|\s\+\S)", s):
            deny("force-push is never allowed.")
        if re.search(r"\b(main|master)\b", s):
            deny("pushing to main is never allowed; main changes only through merged PRs.")
        try:
            branch = subprocess.check_output(["git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD"], text=True).strip()
        except Exception:
            branch = "?"
        if not re.match(r"^(build|scope)/REQ-\d+$", branch):
            deny(f"push only from build/REQ-* or scope/REQ-* branches (current branch: {branch}).")
    if re.search(r"\bsf\s+(data|apex|sobject|org\s+display|project\s+(deploy|retrieve))\b", s):
        m = re.search(r"(?:^|\s)(?:-o|--target-org)(?:=|\s+)(\S+)", s)
        if not m:
            deny("name the target org explicitly with -o <alias>; implicit default orgs are not allowed.")
        alias = m.group(1).strip("'\"")
        if alias not in allowed_aliases and not alias.startswith("$"):
            deny(f"org '{alias}' is not in config/allowed-orgs.json. The agent only talks to allowlisted non-production orgs.")
sys.exit(0)
PY
