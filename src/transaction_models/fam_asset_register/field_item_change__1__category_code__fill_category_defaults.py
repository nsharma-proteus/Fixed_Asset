# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_register
# event_type: field_item_change
# function_name: fill_category_defaults
# form_no: 1
# field_name: category_code
# language: python
# description: Fill the category's name and its Companies Act / Income Tax defaults
# functional_specification: When CATEGORY_CODE changes, read FAM_ASSET_CATEGORY_MASTER for it and fill CATEGORY_NAME, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_METHOD (from COMPANIES_ACT_DEFAULT_METHOD), COMPANIES_ACT_RESIDUAL_VALUE_PCT and INCOME_TAX_BLOCK_CODE, plus INCOME_TAX_BLOCK_DESCR from FAM_DEP_RATE_IT_MASTER for that block; COMPANIES_ACT_RESIDUAL_VALUE = round((PURCHASE_COST + OTHER_CAPITALIZED_COST) * residual pct / 100, 2). No matching category (or the code cleared) clears every one of them and sets the residual value to 0. Same fills as the former rule, plus the two names.
# business_logic: Fill the category's name and its Companies Act / Income Tax defaults


def _get(row, name):
    if not isinstance(row, dict):
        return None
    for k, v in row.items():
        if str(k).lower() == name.lower():
            return v
    return None


def run(args):
    code = str(_get(args, 'CATEGORY_CODE') or '').strip()
    cat = None
    if code:
        cat = db.query_one(
            'SELECT CATEGORY_NAME, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_DEFAULT_METHOD, '
            'COMPANIES_ACT_RESIDUAL_VALUE_PCT, INCOME_TAX_BLOCK_CODE FROM '
            + db.t('FAM_ASSET_CATEGORY_MASTER') + ' WHERE CATEGORY_CODE = :c',
            {'c': code},
        )
    if not cat:
        # As the former rule did on no match: clear what the category fills.
        return {'updates': {
            'category_name': '',
            'companies_act_useful_life_years': '',
            'companies_act_method': '',
            'companies_act_residual_value_pct': '',
            'income_tax_block_code': '',
            'income_tax_block_descr': '',
            'companies_act_residual_value': 0,
        }}
    block = _get(cat, 'INCOME_TAX_BLOCK_CODE')
    block_row = db.query_one(
        'SELECT BLOCK_DESCRIPTION FROM ' + db.t('FAM_DEP_RATE_IT_MASTER') + ' WHERE BLOCK_CODE = :b',
        {'b': block},
    ) if block else None
    pct = float(to_number(_get(cat, 'COMPANIES_ACT_RESIDUAL_VALUE_PCT')) or 0)
    cost = float(to_number(_get(args, 'PURCHASE_COST')) or 0) + float(to_number(_get(args, 'OTHER_CAPITALIZED_COST')) or 0)
    return {'updates': {
        'category_name': _get(cat, 'CATEGORY_NAME') or '',
        'companies_act_useful_life_years': _get(cat, 'COMPANIES_ACT_USEFUL_LIFE_YEARS'),
        'companies_act_method': _get(cat, 'COMPANIES_ACT_DEFAULT_METHOD'),
        'companies_act_residual_value_pct': _get(cat, 'COMPANIES_ACT_RESIDUAL_VALUE_PCT'),
        'income_tax_block_code': block,
        'income_tax_block_descr': _get(block_row, 'BLOCK_DESCRIPTION') or '',
        'companies_act_residual_value': round(cost * pct / 100, 2),
    }}
