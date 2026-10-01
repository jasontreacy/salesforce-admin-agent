# Org notes — lakeside-dev (Lakeside Outfitters, fictional)

Facts already learned about the org. Read before querying; do not re-query what is here.
Humans add lines; the agent offers them.

- **Edition:** Developer Edition, `IsSandbox=false`, org id `00Dak00000fRqpJEAS`. Passes `guard-org.sh` because of the edition, not because it is a sandbox.
- **Opportunity:** no record types. Two layouts: `Opportunity Layout` (source-tracked in this repo) and `Opportunity (Support) Layout` (not tracked). Stages are the Salesforce defaults; `Closed Won` and `Closed Lost` are the only closed stages. One validation rule: `Rush_Order_Close_Within_14_Days`.
- **Lead:** `Unqualified_Reason__c` is restricted and backed by the Global Value Set `Lakeside_Unqualified_Reasons`; no controlling field. Today it is the only field using that set.
- **Case:** `Lakeside_Case_Warranty_Priority` (before-save flow) sets Priority = High when `Warranty_Claim__c` is true.
- **Permissions:** `Lakeside_Wholesale_Rep` is the only custom permission set that grants FLS on Lakeside fields. New Lakeside fields need a `fieldPermissions` entry there or reps will not see them.
- **Leftovers:** the org carries three sample Apex classes from before it was adopted for this project (`tt_UtilController`, `tt_UtilControllerTest`, `AccountController`). They are not in this repo and have 0% aggregate coverage, which is why `scripts/validate.sh` defaults to `TEST_LEVEL=NoTestRun`.
- **Sample fields:** the stock Developer Edition sample custom fields (`Opportunity.OrderNumber__c`, `Lead.SICCode__c`, etc.) exist in the org and on the tracked layout. Leave them alone.
