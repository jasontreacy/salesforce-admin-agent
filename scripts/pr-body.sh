#!/usr/bin/env bash
# pr-body: render the pull-request description for a build PR from the scope and the
# local validation result. Keeps the PR honest: what was asked, what changed, what was proven.
# usage: pr-body.sh scopes/REQ-xxx.md validate-result.json
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCOPE="${1:?usage: pr-body.sh <scope-file> <validate.json>}"
RESULT="${2:?usage: pr-body.sh <scope-file> <validate.json>}"
cd "$ROOT"
CHANGED="$(git diff --name-status main...HEAD -- force-app 2>/dev/null || true)"

python3 - "$SCOPE" "$RESULT" "$ROOT" "$CHANGED" <<'PY'
import json, os, re, sys
scope, result, root, changed = sys.argv[1:5]
sys.path.insert(0, os.path.join(root, "scripts", "lib"))
from frontmatter import read
meta, body = read(scope)
r = json.load(open(result)).get("result", {})
m = re.search(r"CONCEPT\s*\n(.*?)\n\s*\n", body, re.S)
concept = m.group(1).strip() if m else "(see scope)"
files = [l.split("\t")[-1] for l in changed.split("\n") if l.strip()]
print(f"""## Build for {meta['id']} — {meta.get('title','')}

**Scope:** [`{scope}`]({scope}) · approved by **{meta.get('approved_by')}** on {meta.get('approved_on')} · tier {meta.get('tier','?')}
**Target org:** `{meta.get('target_org')}` (allowlisted non-production org; see `config/allowed-orgs.json`)

### Concept
{concept}

### Metadata changed
""" + "\n".join(f"- `{f}`" for f in files) + f"""

Declared in scope: {', '.join(meta.get('metadata_types', []))}

### Local validation (check-only)
- Deployment id `{r.get('id')}` · status **{r.get('status')}** · checkOnly = `{r.get('checkOnly')}`
- Components {r.get('numberComponentsDeployed')}/{r.get('numberComponentsTotal')} · tests {r.get('numberTestsCompleted',0)}/{r.get('numberTestsTotal',0)}

CI will repeat this validation independently and post the result below.

### What the reviewer is deciding
- [ ] The metadata matches the approved scope and nothing more
- [ ] OUTCOMES in the scope would be true after this deploys
- [ ] Blast radius noted in CONSIDERATIONS is acceptable

### What this PR does not do
It does not merge itself, and merging does not deploy. Deployment to the dev org is a separate,
human-approved workflow run (`deploy.yml`, GitHub environment approval). No production org is
reachable from this repository.

---
Opened by the build-scope agent. Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
🤖 Generated with [Claude Code](https://claude.com/claude-code)""")
PY
