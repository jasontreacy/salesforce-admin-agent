---
name: scope-request
description: Phase 1 of the admin agent. Turn a client request in requests/REQ-xxx.md into a dev-ready scope by inspecting the allowlisted Salesforce org read-only with the sf CLI. Writes scopes/REQ-xxx.md with status draft and opens a scope/REQ-xxx pull request for a human to approve. Never changes the org. Use when asked to "scope REQ-xxx", "what's involved in this request", or "what is this ticket really asking".
---

# Scope a request

You are scoping work for a Salesforce admin team. The request file is a client's one-line
theory of their problem, written by someone who does not know the system. **Never write a
scope from the request alone. Go look at the org.**

You write for two audiences at once:

1. **The builder** (Phase 2 of this agent, or a human admin). Needs a spec precise enough to
   execute without follow-up questions. That is the scope block.
2. **The approver** (a human who is sharp but not a Salesforce developer). Needs to understand
   the problem well enough to say yes or no. That is the PLAIN ENGLISH block. It is not optional.

If the approver has to ask "wait, what is this actually doing?", the skill failed.

## Rule zero — read only

This skill changes nothing in the org. Permitted: `sf data query` (including `--use-tooling-api`),
`sf sobject describe`, `sf sobject list`, `sf project retrieve start` **into `.tmp/`** (never into
`force-app/`), `sf org display`. Always pass `-o <alias>` with an alias from
`config/allowed-orgs.json`. The hook in `.claude/hooks/guard-commands.sh` blocks everything else.

The scope is delivered as a **pull request**, not as a change to `main`. A human edits the
front matter to `status: approved` and merges. You never set `status: approved` yourself.

## Workflow

### 1. Read the request and triage — read `references/triage.md`
State the tier in one line before querying. Most requests are Tier 1 (config): two to four
targeted queries, no metadata retrieve, no blast-radius sweep. Tier 3 (bug) digs until it finds
the cause. Tier 4 (too big, or decided outside the org) is not scoped; say so.

### 2. Read what is already known — `references/org-notes.md`
Facts already learned about the org. If the answer is there, do not spend a query on it.

### 3. Investigate to the tier's depth — `references/investigation.md`
You are hunting for the **specific named metadata** the build will touch, the **actual cause**
if it is a bug, the **blast radius** to the tier's depth, and the **open decisions** the client
has not answered.

**Verify the premise before you scope the fix.** If the request says "X is broken", check
whether X is broken. Disproving a false premise is often the most valuable thing you produce.

**Never scope with a known unknown.** If a fact would change the build and you cannot get it
from the org or the request, stop, write the scope as far as it goes, set `status: blocked`,
and put the exact question in the PLAIN ENGLISH block. An unfinished scope with one clear
question beats a complete scope built on an assumption.

**Never invent an API name.** If you did not see it in CLI output, it does not go in the scope.

### 4. Write the scope — follow `references/scope-format.md` exactly
Create `scopes/REQ-xxx.md` with this front matter (the guards parse it; keep the shape exact):

```
---
id: REQ-001
title: <short title>
status: draft
tier: <1|2|3|4>
target_org: lakeside-dev
metadata_types: [CustomField, ValidationRule]
approved_by:
approved_on:
---
```

`metadata_types` is the contract: Phase 2 may touch those types and no others, and every type
must be in `config/metadata-allowlist.json`. If the request needs a type that is not allowed,
the scope is `status: blocked` with the reason. Then the body: PLAIN ENGLISH, then CONCEPT /
TASKS / CONSIDERATIONS / OUTCOMES, then a short delivery note (effort, where to test, what the
approver should decide).

**Length tracks the work.** A Tier 1 scope is four lines of PLAIN ENGLISH and a four-line scope.
Do not pad to look thorough.

### 5. Open the scope PR and stop
```bash
git switch -c scope/REQ-xxx
git add scopes/REQ-xxx.md
git commit -m "scope: REQ-xxx <title>"
git push -u origin scope/REQ-xxx
gh pr create --title "Scope REQ-xxx: <title>" --body-file <(printf '%s\n' "Scope for review. To approve: edit the front matter to status: approved, fill approved_by / approved_on, and merge. Then run the build-scope skill.")
```
Print the PR URL. **Do not** approve, merge, or start building. Phase 2 starts only from a scope
that is on `main` with `status: approved`.

## Hard-won rules
- The request is the worst source of truth you have. Verify its premise.
- Pick the tier first, say it, and hold to its query budget. Over-investigating a picklist add is a real failure, not a safe default.
- CONCEPT is the ask, not the why. Anything interesting about *why* goes in PLAIN ENGLISH.
- Do not manufacture open questions. If a sensible default exists, take it and note the assumption in CONSIDERATIONS.
- A caveat is not a task. It goes in CONSIDERATIONS.
- OUTCOMES is the observable end state, usually one line. Not a test matrix.
- Prefer repurposing existing metadata over building new. Check before you create.
- If you learned a durable fact about the org, offer a line for `references/org-notes.md`. A human adds it.
