# project: Fixed_Asset
# object_type: T
# object_name: fam_warranty_details
# event_type: form_validation
# function_name: check_warranty_period_overlap
# form_no: 1
# language: python
# description: Refuse a new warranty whose period overlaps an existing warranty of the same asset
# functional_specification: On a NEW warranty (_action='add') only: if another FAM_WARRANTY_DETAILS row of the same ASSET_CODE has a period that overlaps WARRANTY_START_DATE..WARRANTY_END_DATE (the same dates, a period lying within an existing one, or any shared day: existing start <= new end AND existing end >= new start), return the error 'Warranty for the selected dates are already available' and block the save. Edits are not checked. Missing asset code or dates are left to the mandatory checks.
# business_logic: Refuse a new warranty whose period overlaps an existing warranty of the same asset

MESSAGE = 'Warranty for the selected dates are already available'


def _get(row, name):
    if not isinstance(row, dict):
        return None
    for k, v in row.items():
        if str(k).lower() == name.lower():
            return v
    return None


def run(args):
    if str(args.get('_action') or '').lower() != 'add':
        return None
    asset_code = str(_get(args, 'ASSET_CODE') or '').strip()
    start = to_date(_get(args, 'WARRANTY_START_DATE'))
    end = to_date(_get(args, 'WARRANTY_END_DATE'))
    if not asset_code or not start or not end:
        return None
    clash = db.scalar(
        'SELECT COUNT(*) FROM ' + db.t('FAM_WARRANTY_DETAILS') + ' '
        'WHERE ASSET_CODE = :a '
        'AND WARRANTY_START_DATE <= :e AND WARRANTY_END_DATE >= :s',
        {'a': asset_code, 's': start, 'e': end},
    )
    if to_number(clash) and to_number(clash) > 0:
        return {'errors': [{'code': 'WARRANTY_PERIOD_OVERLAP', 'field': 'warranty_start_date',
                            'type': 'E', 'message': MESSAGE}],
                'error': MESSAGE}
    return None
