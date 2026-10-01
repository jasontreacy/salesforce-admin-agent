# Scopes

One file per request. The front matter is parsed by the guards; the body is for people.

**Approval is a human act.** The agent opens a scope as `status: draft` (or `blocked`) in a
`scope/REQ-xxx` pull request. A person edits the front matter to `status: approved`, fills in
`approved_by` and `approved_on`, and merges. Only then can the build skill touch it, and a build
PR cannot modify anything in this folder (`scripts/guard-pr-paths.sh`), so it cannot approve itself.

| Field | Meaning |
|---|---|
| `status` | `draft` → `approved` by a human, or `blocked` when the agent cannot or may not build it |
| `tier` | 1 config · 2 standard build · 3 bug · 4 too big to scope alone |
| `target_org` | alias from `config/allowed-orgs.json`; the live org id is re-checked before any validation |
| `metadata_types` | the contract: the build may touch these types and nothing else, each in `config/metadata-allowlist.json` |
