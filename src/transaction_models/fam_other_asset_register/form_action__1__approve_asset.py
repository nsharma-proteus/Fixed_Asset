# project: Fixed_Asset
# object_type: T
# object_name: fam_other_asset_register
# event_type: form_action
# function_name: approve_asset
# form_no: 1
# action_name: Approve
# language: python
# description: Approve/confirm the record
# functional_specification: Set STATUS to 'CAPITALIZED' and lock the core fields (PURCHASE_COST, CAPITALIZATION_DATE, CATEGORY_CODE, OPENING_ACCUMULATED_DEPRECIATION) so they cannot be changed once approved, by returning them as protected cells. Return {"updates": {"status": "CAPITALIZED", "purchase_cost": {"protect": "1"}, "capitalization_date": {"protect": "1"}, "category_code": {"protect": "1"}, "opening_accumulated_depreciation": {"protect": "1"}}}. For an ASSET_TYPE = 'FIXED_ASSET' row, STATUS = 'CAPITALIZED' means the asset is now capitalized and becomes eligible for depreciation processing and visible in Locations & Assignment, Depreciation, Lifecycle and Verification activities. For an ASSET_TYPE = 'OTHER_ASSET' row (every row reachable from THIS screen), STATUS = 'CAPITALIZED' carries NO capitalization/depreciation meaning at all — it simply means the record is confirmed/active in the register (the same status code is reused for both types purely so Transfer/Verification's existing 'must be Capitalized/Active' checks keep working unmodified for Other Asset rows too). CAPITALIZATION_DATE and OPENING_ACCUMULATED_DEPRECIATION do not exist as columns on the fam_other_asset_register form; protecting them via a cell update on a column absent from the calling form is a no-op and must not error. This function is shared by both the fam_asset_register (Fixed Asset Register) and fam_other_asset_register (Other Asset Register) transaction screens, which both write FAM_ASSET_REGISTER rows distinguished only by ASSET_TYPE.
# business_logic: Approve/confirm the record

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
