# project: Fixed_Asset
# object_type: T
# object_name: fam_physical_verification
# event_type: field_item_change
# function_name: refresh_lines_on_branch
# form_no: 1
# field_name: branch_code
# language: python
# description: Keep the branch_code fill and list the assets due for verification in Verification Lines
# functional_specification: Header item change of Conduct Physical Verification. (1) Keep what the field's old rule did: BRANCH_CODE fills BRANCH_NAME and clears LOCATION_CODE/LOCATION_NAME; LOCATION_CODE fills LOCATION_NAME (location of the selected branch); CATEGORY_CODE fills CATEGORY_NAME; NOT_VERIFIED_SINCE_MONTHS fills nothing. (2) While the cycle is new or PLANNED: offer as Verification Lines (form 2, a row_select form - the user ticks the ones to verify) every CAPITALIZED asset of the branch (and of the location / category when set) whose LAST_VERIFIED_DATE is empty or older than today minus NOT_VERIFIED_SINCE_MONTHS months (0 = all), one line per asset with ASSET_CODE, ASSET_NAME, EXPECTED_LOCATION_CODE/NAME and EXPECTED_EMPLOYEE_CODE/NAME from the register. No branch, or no matching asset, empties the lines. Saved (ticked) lines are never dropped; once the cycle leaves PLANNED no candidates are offered.
# business_logic: Keep the branch_code fill and list the assets due for verification in Verification Lines

FIELD = 'branch_code'


def _get(row, name):
    if not isinstance(row, dict):
        return None
    for k, v in row.items():
        if str(k).lower() == name.lower():
            return v
    return None


def _txt(v):
    return str(v or '').strip()


def _months_ago(n):
    d = datetime.date.today()
    y, m = divmod(d.month - 1 - n, 12)
    y, m = d.year + y, m + 1
    last = [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28, 31, 30, 31, 30,
            31, 31, 30, 31, 30, 31][m - 1]
    return datetime.date(y, m, min(d.day, last))


def _header_fill(branch, location, category):
    """What the field's former rule filled."""
    out = {}
    if FIELD == 'branch_code':
        row = db.query_one('SELECT BRANCH_NAME FROM ' + db.t('FAM_BRANCH_MASTER') + ' WHERE BRANCH_CODE = :b',
                           {'b': branch}) if branch else None
        out.update({'branch_name': _get(row, 'BRANCH_NAME') if row else '',
                    'location_code': '', 'location_name': ''})
    elif FIELD == 'location_code':
        row = db.query_one('SELECT LOCATION_NAME FROM ' + db.t('FAM_LOCATION_MASTER')
                           + ' WHERE BRANCH_CODE = :b AND LOCATION_CODE = :l',
                           {'b': branch, 'l': location}) if branch and location else None
        out['location_name'] = _get(row, 'LOCATION_NAME') if row else ''
    elif FIELD == 'category_code':
        row = db.query_one('SELECT CATEGORY_NAME FROM ' + db.t('FAM_ASSET_CATEGORY_MASTER')
                           + ' WHERE CATEGORY_CODE = :c', {'c': category}) if category else None
        out['category_name'] = _get(row, 'CATEGORY_NAME') if row else ''
    return out


def run(args):
    branch = _txt(_get(args, 'BRANCH_CODE'))
    # A branch change clears the location before the list is built.
    location = '' if FIELD == 'branch_code' else _txt(_get(args, 'LOCATION_CODE'))
    category = _txt(_get(args, 'CATEGORY_CODE'))
    forms = {}
    fill = _header_fill(branch, location, category)
    if fill:
        # A plain {column: value} section sets the header's fields.
        forms['1'] = fill
    # Candidates are listed while the cycle is being planned (new, or saved and
    # still PLANNED). Verification Lines is a row_select form: the user ticks
    # the assets to verify, only ticked lines are saved, and a refresh never
    # drops a saved line. Once verification starts the saved lines stand alone.
    if _txt(_get(args, 'STATUS')).upper() in ('', 'PLANNED'):
        rows = []
        if branch:
            sql = ('SELECT a.ASSET_CODE, a.ASSET_NAME, a.LOCATION_CODE, l.LOCATION_NAME, '
                   'a.ASSIGNED_EMPLOYEE_CODE, e.EMPLOYEE_NAME '
                   'FROM ' + db.t('FAM_ASSET_REGISTER') + ' a '
                   'LEFT JOIN ' + db.t('FAM_LOCATION_MASTER') + ' l '
                   'ON l.BRANCH_CODE = a.BRANCH_CODE AND l.LOCATION_CODE = a.LOCATION_CODE '
                   'LEFT JOIN ' + db.t('FAM_EMPLOYEE_MASTER') + ' e ON e.EMPLOYEE_CODE = a.ASSIGNED_EMPLOYEE_CODE '
                   "WHERE a.STATUS = 'CAPITALIZED' AND a.BRANCH_CODE = :b")
            params = {'b': branch}
            if location:
                sql += ' AND a.LOCATION_CODE = :l'
                params['l'] = location
            if category:
                sql += ' AND a.CATEGORY_CODE = :c'
                params['c'] = category
            months = int(to_number(_get(args, 'NOT_VERIFIED_SINCE_MONTHS')) or 0)
            if months > 0:
                sql += ' AND (a.LAST_VERIFIED_DATE IS NULL OR a.LAST_VERIFIED_DATE < :cut)'
                params['cut'] = _months_ago(months)
            sql += ' ORDER BY a.LOCATION_CODE, a.ASSET_CODE'
            for r in db.query(sql, params) or []:
                rows.append({
                    'asset_code': _get(r, 'ASSET_CODE'),
                    'asset_name': _get(r, 'ASSET_NAME'),
                    'expected_location_code': _get(r, 'LOCATION_CODE'),
                    'expected_location_name': _get(r, 'LOCATION_NAME'),
                    'expected_employee_code': _get(r, 'ASSIGNED_EMPLOYEE_CODE'),
                    'expected_employee_name': _get(r, 'EMPLOYEE_NAME'),
                })
        forms['2'] = {'replace': True, 'rows': rows}
    return {'forms': forms} if forms else None
