#!/usr/bin/env bash
# Tests for the guards. No org access needed; everything runs on fixtures and a throwaway git repo.
# Run locally with `scripts/tests/run.sh`; CI runs it on every PR before anything else.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
expect() { # expect <0|nonzero> <name> <cmd...>
  local want="$1" name="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local rc=$?
  if { [ "$want" = 0 ] && [ $rc -eq 0 ]; } || { [ "$want" != 0 ] && [ $rc -ne 0 ]; }; then
    PASS=$((PASS+1)); echo "  ok   $name"
  else
    FAIL=$((FAIL+1)); echo "  FAIL $name (exit $rc, wanted $want)"; echo "$out" | sed 's/^/       /'
  fi
}
hook() { # hook <command-string>  -> runs the PreToolUse hook as Claude Code would
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" \
    | CLAUDE_PROJECT_DIR="$ROOT" bash "$ROOT/.claude/hooks/guard-commands.sh"
}

echo "guard-scope"
mk_scope() { # mk_scope <file> <status> <types> [approved_on]
  cat > "$1" <<S
---
id: $(basename "$1" .md)
title: fixture
status: $2
tier: 1
target_org: lakeside-dev
metadata_types: [$3]
approved_by: someone
approved_on: ${4:-2026-10-01}
---
CONCEPT
fixture
S
}
mkdir -p "$TMP/scopes"
mk_scope "$TMP/scopes/REQ-900.md" approved "CustomField, ValidationRule"
mk_scope "$TMP/scopes/REQ-901.md" draft "CustomField"
mk_scope "$TMP/scopes/REQ-902.md" approved "Profile"
mk_scope "$TMP/scopes/REQ-903.md" approved "CustomField" 2999-01-01
mk_scope "$TMP/scopes/REQ-904.md" approved ""
sed -i.bak 's/^target_org: .*/target_org: production/' "$TMP/scopes/REQ-900.md" && cp "$TMP/scopes/REQ-900.md" "$TMP/scopes/REQ-905.md" && mv "$TMP/scopes/REQ-900.md.bak" "$TMP/scopes/REQ-900.md"
sed -i.bak 's/^id: .*/id: REQ-905/' "$TMP/scopes/REQ-905.md"
expect 0 "approved scope passes"                "$ROOT/scripts/guard-scope.sh" "$TMP/scopes/REQ-900.md"
expect 1 "draft scope is refused"               "$ROOT/scripts/guard-scope.sh" "$TMP/scopes/REQ-901.md"
expect 1 "denied metadata type is refused"      "$ROOT/scripts/guard-scope.sh" "$TMP/scopes/REQ-902.md"
expect 1 "future approval date is refused"      "$ROOT/scripts/guard-scope.sh" "$TMP/scopes/REQ-903.md"
expect 1 "empty metadata_types is refused"      "$ROOT/scripts/guard-scope.sh" "$TMP/scopes/REQ-904.md"
expect 1 "unlisted target org is refused"       "$ROOT/scripts/guard-scope.sh" "$TMP/scopes/REQ-905.md"
expect 1 "missing scope file is refused"        "$ROOT/scripts/guard-scope.sh" "$TMP/scopes/REQ-999.md"

echo "guard-metadata / guard-pr-paths (throwaway git repo)"
R="$TMP/repo"; mkdir -p "$R" && cp -R "$ROOT/scripts" "$ROOT/config" "$R/" && mkdir -p "$R/force-app/main/default/objects/Lead/fields" "$R/scopes"
cd "$R" && git init -q -b main && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
mk_scope "$R/scopes/REQ-910.md" approved "CustomField"
echo '<x/>' > force-app/main/default/objects/Lead/fields/Old__c.field-meta.xml
git add -A && git -c user.name=t -c user.email=t@t commit -q -m baseline
git switch -q -c build/REQ-910
echo '<new/>' > force-app/main/default/objects/Lead/fields/New__c.field-meta.xml
git add -A && git -c user.name=t -c user.email=t@t commit -q -m "add field"
expect 0 "in-scope CustomField passes"          "$R/scripts/guard-metadata.sh" main scopes/REQ-910.md
expect 0 "build branch touching force-app only" "$R/scripts/guard-pr-paths.sh" main build/REQ-910
mkdir -p force-app/main/default/profiles && echo '<x/>' > force-app/main/default/profiles/Admin.profile-meta.xml
git add -A && git -c user.name=t -c user.email=t@t commit -q -m "sneak a profile"
expect 1 "Profile change is refused"            "$R/scripts/guard-metadata.sh" main scopes/REQ-910.md
git reset -q --hard HEAD~1
mkdir -p force-app/main/default/objects/Lead/validationRules && echo '<x/>' > force-app/main/default/objects/Lead/validationRules/VR.validationRule-meta.xml
git add -A && git -c user.name=t -c user.email=t@t commit -q -m "undeclared type"
expect 1 "allowed type NOT declared in scope is refused" "$R/scripts/guard-metadata.sh" main scopes/REQ-910.md
git reset -q --hard HEAD~1
git rm -q force-app/main/default/objects/Lead/fields/Old__c.field-meta.xml && git -c user.name=t -c user.email=t@t commit -q -m "delete"
expect 1 "deletion is refused"                  "$R/scripts/guard-metadata.sh" main scopes/REQ-910.md
git reset -q --hard HEAD~1
sed -i.bak 's/^status: approved/status: draft/' scopes/REQ-910.md && rm scopes/REQ-910.md.bak && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "edit own scope"
expect 1 "build branch editing its scope is refused" "$R/scripts/guard-pr-paths.sh" main build/REQ-910
git reset -q --hard HEAD~1
echo x > scripts/validate.sh && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "edit guard"
expect 1 "build branch editing a guard script is refused" "$R/scripts/guard-pr-paths.sh" main build/REQ-910
git reset -q --hard HEAD~1
git switch -q main && git switch -q -c scope/REQ-911 && mk_scope scopes/REQ-911.md draft "CustomField" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m scope
expect 0 "scope branch adding only its scope passes" "$R/scripts/guard-pr-paths.sh" main scope/REQ-911
echo '<x/>' > force-app/main/default/objects/Lead/fields/Sneak__c.field-meta.xml && git add -A && git -c user.name=t -c user.email=t@t commit -q -m sneak
expect 1 "scope branch touching metadata is refused" "$R/scripts/guard-pr-paths.sh" main scope/REQ-911
cd "$ROOT"

echo "hook: guard-commands.sh"
expect 0 "read query to allowlisted org"        hook "sf data query -o lakeside-dev -q 'SELECT Id FROM Account'"
expect 0 "dry-run deploy allowed"               hook "sf project deploy start -o lakeside-dev --dry-run --source-dir force-app"
expect 2 "real deploy blocked"                  hook "sf project deploy start -o lakeside-dev --source-dir force-app"
expect 2 "deploy hidden behind cd && blocked"   hook "cd force-app && sf project deploy start -o lakeside-dev"
expect 2 "quick deploy blocked"                 hook "sf project deploy quick -o lakeside-dev --job-id 0Af"
expect 2 "record delete blocked"                hook "sf data delete record -o lakeside-dev -s Account -i 001"
expect 2 "anonymous apex blocked"               hook "sf apex run -o lakeside-dev -f x.apex"
expect 2 "unlisted org blocked"                 hook "sf data query -o some-production-alias -q 'SELECT Id FROM Account'"
expect 2 "implicit default org blocked"         hook "sf data query -q 'SELECT Id FROM Account'"
expect 2 "pr merge blocked"                     hook "gh pr merge 1 --squash"
expect 2 "pr self-review blocked"               hook "gh pr review 1 --approve"
expect 2 "push to main blocked"                 hook "git push origin main"
expect 2 "force push blocked"                   hook "git push --force origin build/REQ-001"
expect 2 "mutating gh api blocked"              hook "gh api -X DELETE repos/x/y"
expect 0 "harmless git status allowed"          hook "git status"

echo
echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
