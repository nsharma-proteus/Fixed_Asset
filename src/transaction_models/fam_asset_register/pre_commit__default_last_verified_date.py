# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_register
# event_type: pre_commit
# function_name: default_last_verified_date
# language: python
# description: Default Last Verified to the Capitalization Date on a new asset
# functional_specification: Before commit, only when a NEW asset is being added (action 'add'): if the header has a CAPITALIZATION_DATE, set LAST_VERIFIED_DATE to that date on the FAM_ASSET_REGISTER row identified by ASSET_CODE, but only while LAST_VERIFIED_DATE is still empty. Edits never change it, so a date stamped by an approved physical verification is kept. The header dict is keyed by form key (column name lower-cased), so read columns without regard to case. Return nothing on success.
# business_logic: Default Last Verified to the Capitalization Date on a new asset


def _get(row, *names):
    """Value for the first of `names` present in `row`, ignoring case (the
    header arrives keyed by form key, the column name lower-cased)."""
    if not isinstance(row, dict):
        return None
    lowered = {str(k).lower(): v for k, v in row.items()}
    for name in names:
        v = lowered.get(str(name).lower())
        if v not in (None, ''):
            return v
    return None


def run(args):
    if str(args.get('action') or args.get('_action') or '').lower() != 'add':
        return None
    header = args.get('header') or {}
    cap_date = _get(header, 'CAPITALIZATION_DATE')
    if cap_date is None or _get(header, 'LAST_VERIFIED_DATE') is not None:
        return None
    asset_code = str(_get(header, 'ASSET_CODE') or args.get('txn_id') or '').strip()
    if not asset_code:
        return None
    db.execute(
        'UPDATE ' + db.t('FAM_ASSET_REGISTER') + ' SET LAST_VERIFIED_DATE = :d '
        'WHERE ASSET_CODE = :c AND LAST_VERIFIED_DATE IS NULL',
        {'d': cap_date, 'c': asset_code},
    )
    return None
