# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_register
# event_type: form_action
# function_name: reject_asset
# form_no: 1
# action_name: Reject
# language: python
# description: Reject a submitted asset (status Rejected)
# functional_specification: Set STATUS to 'REJECTED' so the submitter can see the asset was turned down; it can then be corrected and resubmitted (Submit for Approval accepts Draft or Rejected) or deleted. Return {"updates": {"status": "REJECTED"}}.
# business_logic: Reject a submitted asset (status Rejected)

def run(args):
    return {'updates': {'STATUS': 'REJECTED'}}
