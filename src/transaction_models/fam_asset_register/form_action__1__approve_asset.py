# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_register
# event_type: form_action
# function_name: approve_asset
# form_no: 1
# action_name: Approve
# language: python
# description: Approve and capitalize the asset
# functional_specification: Set STATUS to 'CAPITALIZED' and lock the core financial fields (PURCHASE_COST, CAPITALIZATION_DATE, CATEGORY_CODE, OPENING_ACCUMULATED_DEPRECIATION) so they cannot be changed once capitalized, by returning them as protected cells. Return {"updates": {"status": "CAPITALIZED", "purchase_cost": {"protect": "1"}, "capitalization_date": {"protect": "1"}, "category_code": {"protect": "1"}, "opening_accumulated_depreciation": {"protect": "1"}}}. Once approved the asset becomes eligible for depreciation processing and visible in Locations & Assignment, Depreciation, Lifecycle and Verification activities.
# business_logic: Approve and capitalize the asset

def run(args):
    return {
        'updates': {
            'STATUS':                            'CAPITALIZED',
            'PURCHASE_COST':                     {'protect': '1'},
            'CAPITALIZATION_DATE':                {'protect': '1'},
            'CATEGORY_CODE':                      {'protect': '1'},
            'OPENING_ACCUMULATED_DEPRECIATION':   {'protect': '1'},
        }
    }
