# The scope format

Four sections, always in this order: **CONCEPT, TASKS, CONSIDERATIONS, OUTCOMES.** Numbered lists
under TASKS, CONSIDERATIONS and OUTCOMES. Preceded by a PLAIN ENGLISH block for the approver.

## Rule one: keep it lean
A complete, shippable Tier 1 scope looks like this. If your output for a comparable request is
meaningfully longer, you are over-producing.

```
CONCEPT
Marcus wants "Price Too High" added to the Unqualified Reason picklist on Lead.

TASKS
1. Add "Price Too High" to the Global Value Set Lakeside_Unqualified_Reasons.
2. Verify the value is selectable on a Lead.

CONSIDERATIONS
1. The value set is shared; the new value appears on every field that uses it (today: only Lead.Unqualified_Reason__c).

OUTCOMES
1. "Price Too High" is selectable as an Unqualified Reason on Lead.
```

## PLAIN ENGLISH — for the approver, written first
Headers, each a sentence or three. Tier 1 requests can collapse this to three to five sentences.

- **What they're asking for** — the request in the client's world, not Salesforce's. Name who asked and what they were trying to do.
- **What's actually going on** — what you found in the org. If the client's theory is wrong, say so plainly.
- **What it takes** — the work in plain terms and roughly how hard.
- **What could go wrong** — blast radius in human terms. Skip on Tier 1 if there is genuinely nothing.
- **What I'm not sure about** — be honest. If everything is confirmed, say so; do not manufacture confidence.

## Section rules
**CONCEPT** — one sentence. Who asked, what they want. Not the why.

**TASKS** — concrete moves with real API names. End with a verify step. Do not manufacture open
questions; take the sensible default and note it in CONSIDERATIONS. A decision gets its own TASKS
line only when it genuinely changes the build.

**CONSIDERATIONS** — the caveats. Often one line. Blast radius, shared metadata, who else is affected.

**OUTCOMES** — what is observably true when done, written so someone can check it. One line is
normal. Add lines only for genuinely distinct outcomes.

## Delivery note (after OUTCOMES)
Three lines: rough effort, where to test, what the approver is really deciding.

## Tone
Plain and direct, like a senior admin handing work to a developer they respect. No "please ensure
that". Say the thing, then stop.
