# project: Fixed_Asset
# object_type: T
# object_name: fam_warranty_details
# event_type: field_item_change
# function_name: load_warranty_history
# form_no: 1
# field_name: asset_code
# language: python
# description: Fill the Warranty History group with the selected asset's earlier warranty records
# functional_specification: When ASSET_CODE changes on the warranty header, read every other FAM_WARRANTY_DETAILS row for that asset (excluding the record being edited, newest end date first) and replace the rows of form 2 (Warranty History) with one read-only line per warranty: its id, provider, start date, end date, status (Active / Expired / Upcoming as of today) and terms. No earlier warranties, or the code cleared, empties the group (the screen then hides it). Changes nothing else on the form.
# business_logic: Fill the Warranty History group with the selected asset's earlier warranty records

def _get(row, name):
    if not isinstance(row, dict):
        return None
    for k, v in row.items():
        if str(k).lower() == name.lower():
            return v
    return None


def _as_date(v):
    # `datetime` is the sandbox's pre-bound datetime module.
    if isinstance(v, datetime.datetime):
        return v.date()
    if isinstance(v, datetime.date):
        return v
    try:
        return datetime.date.fromisoformat(str(v)[:10])
    except (TypeError, ValueError):
        return None


def run(args):
    asset_code = str(_get(args, 'ASSET_CODE') or '').strip()
    current_id = str(_get(args, 'ID') or '').strip()
    rows = []
    if asset_code:
        found = db.query(
            'SELECT ID, WARRANTY_PROVIDER_VENDOR_CODE, WARRANTY_START_DATE, '
            'WARRANTY_END_DATE, WARRANTY_TERMS '
            'FROM ' + db.t('FAM_WARRANTY_DETAILS') + ' '
            'WHERE ASSET_CODE = :a '
            'ORDER BY WARRANTY_END_DATE DESC, ID DESC',
            {'a': asset_code},
        ) or []
        today = datetime.date.today()
        for r in found:
            wid = _get(r, 'ID')
            if current_id and str(wid) == current_id:
                continue
            start, end = _as_date(_get(r, 'WARRANTY_START_DATE')), _as_date(_get(r, 'WARRANTY_END_DATE'))
            if start and start > today:
                status = 'Upcoming'
            elif end and end < today:
                status = 'Expired'
            else:
                status = 'Active'
            rows.append({
                'hist_warranty_id': wid,
                'provider': _get(r, 'WARRANTY_PROVIDER_VENDOR_CODE'),
                'start_date': _get(r, 'WARRANTY_START_DATE'),
                'end_date': _get(r, 'WARRANTY_END_DATE'),
                'warranty_status': status,
                'terms': _get(r, 'WARRANTY_TERMS'),
            })
    # replace with no rows == clear the group (the screen hides an empty one)
    return {'forms': {'2': {'replace': True, 'rows': rows}}}
