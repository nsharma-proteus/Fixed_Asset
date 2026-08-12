# project: Fixed_Asset
# object_type: T
# object_name: fam_other_asset_register
# event_type: form_action
# function_name: submit_asset_for_approval
# form_no: 1
# action_name: Submit for Approval
# language: python
# description: Submit a draft record for approval
# functional_specification: Confirm that ASSET_NAME, CATEGORY_CODE, BRANCH_CODE, LOCATION_CODE, PURCHASE_DATE and PURCHASE_COST are all populated for every asset regardless of ASSET_TYPE. Additionally, when ASSET_TYPE = 'FIXED_ASSET', CAPITALIZATION_DATE must also be populated (it is NOT required when ASSET_TYPE = 'OTHER_ASSET' — Other Assets are never capitalized/depreciated). If any required field is missing return {"error": "..."} naming the missing field(s). Otherwise set STATUS to 'PENDING_APPROVAL' and return {"updates": {"status": "PENDING_APPROVAL"}}. This function is shared by both the fam_asset_register (Fixed Asset Register) and fam_other_asset_register (Other Asset Register) transaction screens, which both write FAM_ASSET_REGISTER rows distinguished only by ASSET_TYPE. Every row reachable from this screen has ASSET_TYPE = 'OTHER_ASSET', so in practice CAPITALIZATION_DATE is never required here.
# business_logic: Submit a draft record for approval

def run(args):
    required = [
        ('ASSET_NAME',    'Asset Name'),
        ('CATEGORY_CODE', 'Category Code'),
        ('BRANCH_CODE',   'Branch Code'),
        ('LOCATION_CODE', 'Location Code'),
        ('PURCHASE_DATE', 'Purchase Date'),
        ('PURCHASE_COST', 'Purchase Cost'),
    ]

    missing = [label for col, label in required if is_empty(args.get(col))]

    # CAPITALIZATION_DATE is only required for FIXED_ASSET rows. Every row
    # reachable from this screen is ASSET_TYPE = 'OTHER_ASSET', so this
    # branch is dead in practice, but the check is kept for parity with the
    # shared fam_asset_register implementation of this same method.
    if args.get('ASSET_TYPE') == 'FIXED_ASSET' and is_empty(args.get('CAPITALIZATION_DATE')):
        missing.append('Capitalization Date')

    if missing:
        return {'error': 'The following required field(s) must be filled before submission: ' + ', '.join(missing)}

    return {'updates': {'STATUS': 'PENDING_APPROVAL'}}
