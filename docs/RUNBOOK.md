# Runbook — set this up against your own Developer Edition org

Everything here is reproducible from a clone in about twenty minutes. You need: a free
[Developer Edition org](https://developer.salesforce.com/signup), the
[Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`), the GitHub CLI
(`gh`), Python 3, and [Claude Code](https://claude.com/claude-code) to run the skills.

## 1. Authenticate and allowlist the org (operator, once)

```bash
sf org login web --alias lakeside-dev
sf data query -o lakeside-dev -q "SELECT Id, OrganizationType, IsSandbox FROM Organization"
```

Put the 18-character org id into `config/allowed-orgs.json`. The alias in the file is what the
skills and workflows use; the id is what `scripts/guard-org.sh` checks against the live org.
`OrganizationType` must be `Developer Edition` or the org must be a sandbox; anything else is
refused by design.

## 2. Seed the fictional client's baseline (operator, once)

This is the one real deployment a human runs from a laptop. It is what the agent is never
allowed to do.

```bash
scripts/validate.sh lakeside-dev           # check-only first, as the agent would
sf project deploy start -o lakeside-dev --source-dir force-app --test-level NoTestRun
```

If your Developer Edition org is brand new it contains no Apex, and you can set
`TEST_LEVEL=RunLocalTests` in both workflows and `scripts/validate.sh`.

## 3. Wire up GitHub (operator, once)

```bash
gh repo create <you>/salesforce-admin-agent --public --source . --push

# CI auth: the org's SFDX auth URL, stored as a repository secret. Never echo it.
# (Recent CLIs redact it from `sf org display`; this is the command that shows it.)
sf org auth show-sfdx-auth-url -o lakeside-dev --json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["sfdxAuthUrl"])' \
  | gh secret set SFDX_AUTH_URL

# The human gate for deployments: an environment that requires your approval.
gh api -X PUT repos/<you>/salesforce-admin-agent/environments/lakeside-developer-edition \
  --input - <<EOF2
{"reviewers":[{"type":"User","id":$(gh api user --jq .id)}],"deployment_branch_policy":{"protected_branches":true,"custom_branch_policies":false}}
EOF2

# main changes only through PRs that passed the `gate` check; admins included.
gh api -X PUT repos/<you>/salesforce-admin-agent/branches/main/protection --input - <<EOF2
{"required_status_checks":{"strict":true,"contexts":["gate"]},"enforce_admins":true,
 "required_pull_request_reviews":null,"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
EOF2
```

Rotate the secret by re-running the `gh secret set` line; revoke it by revoking the refresh token
in the org (Setup → Connected Apps OAuth Usage → Salesforce CLI).

## 4. Run the agent

Open the repo in Claude Code. The project settings and hook load from `.claude/` automatically.

```
> scope REQ-002
```
The `scope-request` skill inspects the org read-only, writes `scopes/REQ-002.md` with
`status: draft`, and opens a `scope/REQ-002` pull request.

**You approve:** on that PR, edit the front matter to `status: approved`, add `approved_by` and
`approved_on`, merge.

```
> build REQ-002
```
The `build-scope` skill runs the guards, writes the metadata, runs a check-only deploy, and opens
a `build/REQ-002` pull request. CI repeats the guards and the validation and comments the result.

**You approve again:** review and merge the PR. The `deploy` workflow starts and waits in the
`lakeside-developer-edition` environment until you click *Approve*. Only then does metadata reach
the org.

## 5. Run the guards by hand

```bash
scripts/tests/run.sh                                  # the guards' own tests, no org needed
scripts/guard-scope.sh scopes/REQ-001.md
scripts/guard-org.sh lakeside-dev
scripts/guard-metadata.sh main scopes/REQ-001.md      # on a build branch
scripts/guard-pr-paths.sh main build/REQ-001
scripts/validate.sh lakeside-dev
```

To try the hook on its own, feed it a tool call the way Claude Code does:

```bash
printf '{"tool_name":"Bash","tool_input":{"command":"sf project deploy start -o lakeside-dev --source-dir force-app"}}' \
  | CLAUDE_PROJECT_DIR=$PWD bash .claude/hooks/guard-commands.sh; echo "exit=$?"
```
