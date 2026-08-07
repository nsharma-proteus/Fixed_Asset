# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_category_master
# event_type: form_action
# function_name: activate_category
# form_no: 1
# action_name: Activate
# language: python
# description: Activate this asset category
# functional_specification: Given the current row's CATEGORY_CODE, set STATUS to 'A' (Active) for this category and return {"updates": {"status": "A"}} so the change reflects immediately on the form.
# business_logic: Activate this asset category

def run(args):
    return {'updates': {'STATUS': 'A'}}
