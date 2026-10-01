---
name: build-scope
description: Phase 2 of the admin agent. Turn an APPROVED scope (scopes/REQ-xxx.md on main with status approved) into Salesforce metadata under force-app/, prove it with a check-only deploy against the allowlisted dev org, and open a build/REQ-xxx pull request for a human to review. Never deploys for real, never merges, never touches production. Use when asked to "build REQ-xxx" or "implement the approved scope".
---

# Build an approved scope

You turn a decided WHAT into metadata, safely. You do not re-scope. If building reveals the
scope is wrong or incomplete, stop and report; do not quietly redesign.

## Rule zero — what you may and may not do

- **Only approved scopes.** `scripts/guard-scope.sh` must pass before you write a single file.
  `status: approved`, set by a human, merged to `main`. You never edit `scopes/`.
- **Only declared metadata.** The scope's `metadata_types` is the contract. `scripts/guard-metadata.sh`
  refuses anything else, and refuses every deletion.
- **Only the allowlisted org, only check-only.** The one deploy-shaped command you run is
  `scripts/validate.sh`, which is a `--dry-run` and asserts `checkOnly=true` from the API response.
  `sf project deploy start` without `--dry-run`, `deploy quick`, `deploy resume`, record writes
  and anonymous Apex are blocked by the hook, and would be refused by CI anyway.
- **Only your own branch.** `build/REQ-xxx`. You may change `force-app/**` and `builds/REQ-xxx.md`.
  Nothing else: not scopes, not config, not scripts, not workflows, not the hook.
- **You never merge.** You open the PR and stop. Merging is a human click; deploying is a second
  human approval in the `deploy` workflow's GitHub environment.

## Steps — run them in this order, and stop at the first failure

```bash
REQ=REQ-001
git switch main && git pull --ff-only
scripts/guard-scope.sh scopes/$REQ.md          # 1. a human approved this
scripts/guard-org.sh lakeside-dev               # 2. the org is the allowlisted non-prod org
git switch -c build/$REQ                        # 3. your branch
```

4. **Read the scope's TASKS and write the metadata** under `force-app/main/default/`. Use the
   existing files as templates for shape and API version. Add FLS for any new field to
   `permissionsets/Lakeside_Wholesale_Rep.permissionset-meta.xml`. Add new fields to the tracked
   layout when the scope says so. Use the API names the scope gives; invent none.

```bash
scripts/guard-metadata.sh main scopes/$REQ.md   # 5. changed types ⊆ scope ⊆ allowlist, no deletions
scripts/validate.sh lakeside-dev validate-result.json   # 6. check-only deploy; must say checkOnly=True, Succeeded
```

7. **Write the build log** `builds/$REQ.md`: date, scope id, files changed, the validation
   deployment id and component count, anything you noticed that the reviewer should know
   (for example a TASKS line you interpreted). Short.

```bash
scripts/guard-pr-paths.sh main build/$REQ        # 8. you touched only force-app/** and builds/REQ.md
git add force-app builds/$REQ.md
git commit -m "build: $REQ <title>" -m "Check-only validation <deploy id> succeeded against lakeside-dev." -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push -u origin build/$REQ
gh pr create --title "Build $REQ: <title>" --body-file <(scripts/pr-body.sh scopes/$REQ.md validate-result.json)
```

9. Print the PR URL and stop. Do not watch CI in a loop, do not re-push to "fix" a red check
   without reading why it is red, and never run `gh pr merge`.

## If something fails
- `guard-scope` fails → the scope is not approved. Say so and stop. Do not "fix" the front matter.
- `guard-metadata` fails → you exceeded the scope. Remove the extra change, or stop and report that the scope needs another type.
- `validate` fails → read the component failures, fix the metadata, re-run. If the failure is a scope problem (the field the scope names does not exist, the formula cannot work), stop and report.
- `validate` says `checkOnly` is not true → stop immediately and report. Something is wrong with the tooling and no further command should run.
