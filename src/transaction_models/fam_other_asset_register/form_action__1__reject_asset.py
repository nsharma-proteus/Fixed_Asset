# project: Fixed_Asset
# object_type: T
# object_name: fam_other_asset_register
# event_type: form_action
# function_name: reject_asset
# form_no: 1
# action_name: Reject
# language: python
# description: Reject a submitted record back to Draft
# functional_specification: Set STATUS back to 'DRAFT' so the record details can be corrected and resubmitted, and return {"updates": {"status": "DRAFT"}}. This function is shared by both the fam_asset_register and fam_other_asset_register transaction screens.
# business_logic: Reject a submitted record back to Draft

def run(args):
    return {'updates': {'STATUS': 'DRAFT'}}
