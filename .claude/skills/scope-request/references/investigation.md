# Investigating the org (read-only)

Goal: leave with **named metadata** and a **cause**, not a theory. Always `-o <alias>`.

```bash
# Fields on an object (fast, no retrieve)
sf sobject describe -o lakeside-dev -s Opportunity --json | python3 -c "import json,sys; [print(f['name'], f['type']) for f in json.load(sys.stdin)['result']['fields'] if f['custom']]"

# Validation rules on an object
sf data query -o lakeside-dev --use-tooling-api -q "SELECT ValidationName, Active, ErrorConditionFormula, ErrorMessage FROM ValidationRule WHERE EntityDefinition.QualifiedApiName='Opportunity'"

# Flows touching an object
sf data query -o lakeside-dev --use-tooling-api -q "SELECT Definition.DeveloperName, VersionNumber, Status, ProcessType, TriggerType FROM Flow WHERE Status='Active'"

# Who has FLS on a field (profiles and permission sets)
sf data query -o lakeside-dev -q "SELECT Parent.Name, Parent.IsOwnedByProfile, PermissionsRead, PermissionsEdit FROM FieldPermissions WHERE Field='Lead.Store_Type__c'"

# Global value sets and the fields that use them
sf data query -o lakeside-dev --use-tooling-api -q "SELECT DeveloperName, MasterLabel FROM GlobalValueSet"

# Record counts to size blast radius (a rule on 40 records is not a rule on 40,000)
sf data query -o lakeside-dev -q "SELECT COUNT() FROM Opportunity WHERE IsClosed=false"

# Recent flow errors (Tier 3)
sf data query -o lakeside-dev --use-tooling-api -q "SELECT FlowVersionId, ElementApiName, ErrorMessage, CreatedDate FROM FlowInterviewLog ORDER BY CreatedDate DESC LIMIT 20"

# Read one piece of metadata in full — ALWAYS into .tmp/, never into force-app/
mkdir -p .tmp && sf project retrieve start -o lakeside-dev -m "Layout:Opportunity-Opportunity Layout" --output-dir .tmp/retrieve
```

## Gotchas
- `FlowDefinitionView` does not exist in SOQL. Use the Tooling API `Flow` / `FlowDefinition` objects.
- `DeveloperName` on Tooling `CustomField` has no `__c` suffix.
- Deactivated picklist values still appear in report filters.
- A validation rule's formula references fields by API name; a field rename does not break it, a field deletion does.
- Required-ness can live in three places: the field definition, a validation rule, or a flow. Check all three before saying "make it required".
