# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_register
# event_type: form_action
# function_name: submit_asset_for_approval
# form_no: 1
# action_name: Submit for Approval
# language: python
# description: Submit a draft asset for approval
# functional_specification: Confirm that ASSET_NAME, CATEGORY_CODE, BRANCH_CODE, LOCATION_CODE, PURCHASE_DATE, PURCHASE_COST and CAPITALIZATION_DATE are all populated; if any is missing return {"error": "..."} naming the missing field(s). Otherwise set STATUS to 'PENDING_APPROVAL' and return {"updates": {"status": "PENDING_APPROVAL"}}.
# business_logic: Submit a draft asset for approval

def run(args):
    required = [
        ('ASSET_NAME',          'Asset Name'),
        ('CATEGORY_CODE',       'Category Code'),
        ('BRANCH_CODE',         'Branch Code'),
        ('LOCATION_CODE',       'Location Code'),
        ('PURCHASE_DATE',       'Purchase Date'),
        ('PURCHASE_COST',       'Purchase Cost'),
        ('CAPITALIZATION_DATE', 'Capitalization Date'),
    ]

    missing = [label for col, label in required if is_empty(args.get(col))]

    if missing:
        return {'error': 'The following required field(s) must be filled before submission: ' + ', '.join(missing)}

    return {'updates': {'STATUS': 'PENDING_APPROVAL'}}
