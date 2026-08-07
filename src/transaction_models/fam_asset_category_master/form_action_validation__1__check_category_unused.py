# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_category_master
# event_type: form_action_validation
# function_name: check_category_unused
# form_no: 1
# action_name: Delete
# language: python
# description: Prevent deleting a category still referenced elsewhere
# functional_specification: Given the CATEGORY_CODE of the row targeted for delete, block the delete (return an error) if the code is referenced by CATEGORY_CODE on any row in FAM_ASSET_REGISTER or FAM_DEP_RATE_CA_MASTER. Return no error (allow delete) when no references are found.
# business_logic: Prevent deleting a category still referenced elsewhere

def run(args):
    category_code = args.get('CATEGORY_CODE')

    # Block if the category is referenced by any asset in the Asset Register
    asset_ref = db.query_one(
        'SELECT ASSET_CODE FROM ' + db.t('FAM_ASSET_REGISTER') +
        ' WHERE CATEGORY_CODE = :code',
        {'code': category_code}
    )
    if asset_ref:
        message = (
            "Category '" + str(category_code) + "' cannot be deleted — "
            "it is in use by the Asset Register."
        )
        return {
            'error': message,
            'errors': [{
                'code': 'CATEGORY_IN_USE_ASSET_REGISTER',
                'field': 'CATEGORY_CODE',
                'type': 'E',
                'message': message
            }]
        }

    # Block if the category is referenced by any row in the Companies Act depreciation rate master
    dep_rate_ref = db.query_one(
        'SELECT CATEGORY_CODE FROM ' + db.t('FAM_DEP_RATE_CA_MASTER') +
        ' WHERE CATEGORY_CODE = :code',
        {'code': category_code}
    )
    if dep_rate_ref:
        message = (
            "Category '" + str(category_code) + "' cannot be deleted — "
            "it is in use by the Companies Act depreciation rate master."
        )
        return {
            'error': message,
            'errors': [{
                'code': 'CATEGORY_IN_USE_DEP_RATE_CA',
                'field': 'CATEGORY_CODE',
                'type': 'E',
                'message': message
            }]
        }

    return None
