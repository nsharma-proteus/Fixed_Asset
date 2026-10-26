# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_installation
# event_type: field_item_change
# function_name: load_asset_transfer_history
# form_no: 1
# field_name: asset_code
# language: python
# description: Fill the Transfer History tab with the selected asset's Asset Transfer records
# functional_specification: When ASSET_CODE changes on the installation header, read every FAM_ASSET_TRANSFER row for that asset (newest first) and replace the rows of form 2 (Transfer History) with one read-only line per transfer: transfer no, date, status, from/to branch and location, to employee, reason. Branch / location / employee names fall back to their masters when the transfer row did not store them. When the asset has no transfers (or the code is cleared), the tab is emptied. Changes nothing else on the form.
# business_logic: Fill the Transfer History tab with the selected asset's Asset Transfer records


def _get(row, name):
    if not isinstance(row, dict):
        return None
    for k, v in row.items():
        if str(k).lower() == name.lower():
            return v
    return None


def run(args):
    asset_code = str(_get(args, 'ASSET_CODE') or '').strip()
    rows = []
    if asset_code:
        found = db.query(
            'SELECT t.TRANSFER_NO, t.TRANSFER_DATE, t.STATUS, t.TRANSFER_REASON, '
            "COALESCE(NULLIF(t.FROM_BRANCH_NAME, ''), fb.BRANCH_NAME, t.FROM_BRANCH_CODE) AS FROM_BRANCH, "
            "COALESCE(NULLIF(t.FROM_LOCATION_NAME, ''), fl.LOCATION_NAME, t.FROM_LOCATION_CODE) AS FROM_LOCATION, "
            "COALESCE(NULLIF(t.TO_BRANCH_NAME, ''), tb.BRANCH_NAME, t.TO_BRANCH_CODE) AS TO_BRANCH, "
            "COALESCE(NULLIF(t.TO_LOCATION_NAME, ''), tl.LOCATION_NAME, t.TO_LOCATION_CODE) AS TO_LOCATION, "
            "COALESCE(NULLIF(t.TO_EMPLOYEE_NAME, ''), te.EMPLOYEE_NAME, t.TO_EMPLOYEE_CODE) AS TO_EMPLOYEE "
            'FROM ' + db.t('FAM_ASSET_TRANSFER') + ' t '
            'LEFT JOIN ' + db.t('FAM_BRANCH_MASTER') + ' fb ON fb.BRANCH_CODE = t.FROM_BRANCH_CODE '
            'LEFT JOIN ' + db.t('FAM_LOCATION_MASTER') + ' fl ON fl.BRANCH_CODE = t.FROM_BRANCH_CODE AND fl.LOCATION_CODE = t.FROM_LOCATION_CODE '
            'LEFT JOIN ' + db.t('FAM_BRANCH_MASTER') + ' tb ON tb.BRANCH_CODE = t.TO_BRANCH_CODE '
            'LEFT JOIN ' + db.t('FAM_LOCATION_MASTER') + ' tl ON tl.BRANCH_CODE = t.TO_BRANCH_CODE AND tl.LOCATION_CODE = t.TO_LOCATION_CODE '
            'LEFT JOIN ' + db.t('FAM_EMPLOYEE_MASTER') + ' te ON te.EMPLOYEE_CODE = t.TO_EMPLOYEE_CODE '
            'WHERE t.ASSET_CODE = :a '
            'ORDER BY t.TRANSFER_DATE DESC, t.TRANSFER_NO DESC',
            {'a': asset_code},
        ) or []
        for r in found:
            rows.append({
                'transfer_no': _get(r, 'TRANSFER_NO'),
                'transfer_date': _get(r, 'TRANSFER_DATE'),
                'transfer_status': _get(r, 'STATUS'),
                'from_branch': _get(r, 'FROM_BRANCH'),
                'from_location': _get(r, 'FROM_LOCATION'),
                'to_branch': _get(r, 'TO_BRANCH'),
                'to_location': _get(r, 'TO_LOCATION'),
                'to_employee': _get(r, 'TO_EMPLOYEE'),
                'transfer_reason': _get(r, 'TRANSFER_REASON'),
            })
    # replace with no rows == clear the tab (no history for this asset)
    return {'forms': {'2': {'replace': True, 'rows': rows}}}
