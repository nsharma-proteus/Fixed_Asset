# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_register
# event_type: form_action
# function_name: reject_asset
# form_no: 1
# action_name: Reject
# language: python
# description: Reject a submitted asset back to Draft
# functional_specification: Set STATUS back to 'DRAFT' so the asset details can be corrected and resubmitted, and return {"updates": {"status": "DRAFT"}}.
# business_logic: Reject a submitted asset back to Draft

def run(args):
    return {'updates': {'STATUS': 'DRAFT'}}
