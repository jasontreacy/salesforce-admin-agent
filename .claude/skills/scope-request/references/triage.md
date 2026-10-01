# Triage first — match the dig to the request

**Before you touch the org, classify the request.** Most are small. Investigating a picklist add
like a production outage wastes everyone's time and buries the answer in ceremony. State the tier
in one line before querying so the approver can redirect you if you called it wrong.

| Tier | What | Budget | Target |
|---|---|---|---|
| **1 — Config** | picklist value, field access, add field to layout, report filter, list view | 2–4 targeted queries, no retrieve, no sweep | under a minute |
| **2 — Standard build** | new field + automation, validation rule, one named flow change | targeted queries + retrieve the ONE thing | a few minutes |
| **3 — Bug** | something is broken; you must find out why | whatever it takes; root cause or it is not a scope | as long as it takes |
| **4 — Too big** | redesign, new object model, integration, "audit", undecided requirements | don't dig; list the decisions | fast; you are not scoping it |

**If you are past the budget and still digging, stop and say so.** Either the tier was wrong
(escalate and say why) or you are stuck (say what you need). Both beat grinding silently.

## Is Salesforce even the right system?
If the request says data is "not coming through from <another system>", Salesforce is probably
downstream. You cannot root-cause an upstream integration from inside the org. Verify whether the
data is arriving (it often is), then if the fix depends on config you cannot read, the request is
Tier 4: say what you proved, name the fork, name the one question that decides it.

## Fast recipes

### Add a picklist value (the most common Tier 1 request)
One Tooling API query answers the whole request:

```bash
ORG=lakeside-dev; OBJ=Lead; FIELD=Unqualified_Reason   # no __c suffix in DeveloperName
sf data query -o $ORG --use-tooling-api \
  -q "SELECT DeveloperName, Metadata FROM CustomField WHERE TableEnumOrId='$OBJ' AND DeveloperName='$FIELD'" --json \
| python3 -c "
import sys,json
v=json.load(sys.stdin)['result']['records'][0]['Metadata']['valueSet']
print('restricted      :', v.get('restricted'))
print('controllingField:', v.get('controllingField'))
print('valueSetName    :', v.get('valueSetName'))"
```
- `restricted: True` → the value must be added to the value set definition, not typed in.
- `valueSetName` set → it is a **Global Value Set**, shared. Adding a value exposes it everywhere the set is used. Check which fields use it.
- `controllingField` set → **dependent picklist**: the value must also be mapped to the controlling value or it never appears.
- All three null/false → a one-click add. Say so and stop.

### Grant field access / "user can't see X"
```bash
sf data query -o $ORG -q "SELECT Parent.Name, Parent.IsOwnedByProfile, PermissionsRead, PermissionsEdit FROM FieldPermissions WHERE Field='Opportunity.Order_Channel__c'"
```

### Add a field to a layout
```bash
sf data query -o $ORG --use-tooling-api -q "SELECT Name FROM Layout WHERE TableEnumOrId='Opportunity'"
sf data query -o $ORG -q "SELECT DeveloperName FROM RecordType WHERE SobjectType='Opportunity' AND IsActive=true"
```
The real question is which layouts, and whether the field would leak to a team that should not see it.

### New field with a rule (Tier 2)
```bash
sf data query -o $ORG --use-tooling-api -q "SELECT ValidationName, Active, ErrorConditionFormula FROM ValidationRule WHERE EntityDefinition.QualifiedApiName='Opportunity'"
sf data query -o $ORG -q "SELECT MasterLabel, IsClosed, IsWon FROM OpportunityStage WHERE IsActive=true ORDER BY SortOrder"
```
Know what already fires on the object before adding another rule.

### Flow is failing (Tier 3)
```bash
sf data query -o $ORG --use-tooling-api -q "SELECT Id, MasterLabel, VersionNumber, Status FROM Flow WHERE Definition.DeveloperName='Lakeside_Case_Warranty_Priority' ORDER BY VersionNumber DESC"
mkdir -p .tmp && sf project retrieve start -o $ORG -m "Flow:Lakeside_Case_Warranty_Priority" --output-dir .tmp/retrieve
```
Read the XML. Look for missing fault connectors, hard-coded ids, updates the running user cannot perform.

## Never do these
- `sf project retrieve start -m "CustomObject:Lead"` on a Tier 1 request. It pulls the whole object.
- Sweeping every flow "to check blast radius" on a config request.
- A five-paragraph explanation for a two-minute job.
