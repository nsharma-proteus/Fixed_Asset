# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_category_master
# event_type: form_action
# function_name: deactivate_category
# form_no: 1
# action_name: Deactivate
# language: python
# description: Deactivate this asset category
# functional_specification: Given the current row's CATEGORY_CODE, set STATUS to 'I' (Inactive) for this category and return {"updates": {"status": "I"}}. Deactivating a category blocks its selection on new Asset Register entries but must not alter any existing asset already carrying this category code.
# business_logic: Deactivate this asset category

def run(args):
    # Only the current FAM_ASSET_CATEGORY_MASTER row is updated via the
    # returned 'updates' dict. No writes are issued against
    # FAM_ASSET_REGISTER, so existing assets referencing this category
    # remain untouched.
    return {'updates': {'STATUS': 'I'}}
