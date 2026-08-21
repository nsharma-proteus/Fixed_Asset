# project: Fixed_Asset
# object_type: T
# object_name: fam_verification_execution
# event_type: form_action
# function_name: scan_asset_by_code
# form_no: 1
# action_name: Scan Asset By Code
# language: python
# description: Resolve the open verification cycle for a scanned asset code and stamp it FOUND
# functional_specification: Invoked by the Assistant scan intent PV_SCAN_ASSET when an asset QR/barcode is scanned, and runs with NO form context. Payload is FLAT and may contain only SCAN_ASSET_CODE_IN (also lowercase); VERIFICATION_CYCLE_NO may be absent or empty. Steps: (1) Read the scanned code from SCAN_ASSET_CODE_IN, falling back to SCAN_ASSET_CODE and ASSET_CODE; trim it and upper-case it; if empty return {"error": "No asset code was scanned."}. (2) If VERIFICATION_CYCLE_NO was supplied use it; otherwise find every FAM_PHYSICAL_VERIFICATION_LINE row for that ASSET_CODE whose parent FAM_PHYSICAL_VERIFICATION has STATUS in ('PLANNED','IN_PROGRESS'). (3) If no such row exists return {"error": "Asset <code> is not on any open verification list."}. (4) If more than one open cycle contains the asset return {"error": "Asset <code> appears on more than one open verification list (<cycles>) - open the cycle and use Scan Asset."}. (5) With exactly one cycle: if that line already has a PHYSICAL_STATUS_FOUND, return a message saying it is already recorded as that status and change nothing. (6) Otherwise UPDATE the line setting PHYSICAL_STATUS_FOUND='FOUND', VERIFIED_DATE=current date, and stamp CHG_DATE/CHG_USER. (7) If the cycle header STATUS is 'PLANNED', UPDATE it to 'IN_PROGRESS'. (8) Return {"message": "Asset <code> (<asset name>) verified on cycle <no>. <n> assets remaining."}. Never insert a line and never verify an asset that is not already on the cycle's list. Additionally: the scanned value is a QR PAYLOAD, not necessarily a bare code - the fam_asset_qr_tag report encodes COALESCE(NULLIF(QR_BARCODE_TAG,''), 'FAM|' || ASSET_CODE) and the Generate QR/Barcode Tag action builds 'FAM|<asset>|<category>|<branch>|<timestamp>', so a leading 'FAM|' prefix (and any trailing pipe-delimited segments) is stripped before matching, as are control characters, a scanner URL wrapper and a JSON/ASSET_CODE=<code> wrapper; a bare asset code keeps working unchanged.
# business_logic: Resolve the open verification cycle for a scanned asset code and stamp it FOUND

# Identifiers are deployed LOWER-case on this Postgres project, and db.t() /
# db.update() quote the names EXACTLY as they are passed - so every table name,
# column name and result-row key handled below is lower-case.


def _normalize_scan_code(raw):
    # The Assistant hands over whatever the camera decoded. That is normally the
    # QR payload 'FAM|<ASSET_CODE>' (or the richer tag the Generate QR/Barcode
    # Tag action builds: 'FAM|<asset>|<category>|<branch>|<timestamp>'), but a
    # device scanner may instead deliver a URL, a key=value blob or a JSON
    # object - reduce any of those to the plain asset code. A bare code that
    # carries no wrapper at all must survive untouched.
    value = re.sub(r'[\x00-\x1f\x7f]', '', str(raw or '')).strip()
    if not value:
        return ''

    if '://' in value or value.lower().startswith('http'):
        path = value.split('#', 1)[0]
        query = ''
        if '?' in path:
            path, query = path.split('?', 1)
        for pair in query.split('&'):
            key, sep, val = pair.partition('=')
            if sep and key.strip().upper() == 'ASSET_CODE':
                value = val.strip()
                break
        else:
            segments = [s for s in path.split('/') if s.strip()]
            value = segments[-1].strip() if segments else ''
    elif 'ASSET_CODE=' in value.upper():
        tail = value[value.upper().index('ASSET_CODE=') + len('ASSET_CODE='):]
        value = re.split(r'[&;,\s]', tail)[0].strip()
    elif value.startswith('{'):
        try:
            parsed = json.loads(value)
        except Exception:
            parsed = None
        if isinstance(parsed, dict):
            value = str(parsed.get('ASSET_CODE') or parsed.get('asset_code') or '').strip()

    value = value.strip()

    # 'FAM|<asset_code>[|<extra>...]' -> the asset code only. Applied last so it
    # also cleans a payload that arrived wrapped in a URL or JSON envelope.
    if re.match(r'^FAM\s*\|', value, re.IGNORECASE):
        value = re.sub(r'^FAM\s*\|\s*', '', value, flags=re.IGNORECASE)
        value = value.split('|', 1)[0]

    return value.strip().upper()


def _cell(row, name):
    # Result-row keys come back in the driver's casing; read either case so the
    # function cannot break on a key-name mismatch.
    if not row:
        return None
    if name in row:
        return row[name]
    lowered = name.lower()
    for key in row:
        if str(key).lower() == lowered:
            return row[key]
    return None


def _text(value):
    return '' if value is None else str(value).strip()


def run(args):
    # Step 1: the scan intent fires with no form open, so the code may arrive
    # under any of these keys (each present in both cases).
    scan_code = _normalize_scan_code(
        args.get('SCAN_ASSET_CODE_IN') or args.get('scan_asset_code_in')
        or args.get('SCAN_ASSET_CODE') or args.get('scan_asset_code')
        or args.get('ASSET_CODE') or args.get('asset_code')
    )
    if not scan_code:
        return {"error": "No asset code was scanned."}

    cycle_in = _text(args.get('VERIFICATION_CYCLE_NO') or args.get('verification_cycle_no'))

    # Step 2: resolve the cycle from the asset itself. Only PLANNED / IN_PROGRESS
    # cycles are stampable, so the header status is part of the match even when a
    # cycle number was supplied - a closed cycle must never be written to.
    sql = (
        'SELECT l.verification_cycle_no, l.line_no, l.physical_status_found,'
        ' h.status AS cycle_status, a.asset_name'
        ' FROM ' + db.t('fam_physical_verification_line') + ' l'
        ' JOIN ' + db.t('fam_physical_verification') + ' h'
        ' ON h.verification_cycle_no = l.verification_cycle_no'
        ' LEFT JOIN ' + db.t('fam_asset_register') + ' a ON a.asset_code = l.asset_code'
        " WHERE l.asset_code = :a AND h.status IN ('PLANNED', 'IN_PROGRESS')"
    )
    params = {'a': scan_code}
    if cycle_in:
        sql += ' AND l.verification_cycle_no = :c'
        params['c'] = cycle_in
    sql += ' ORDER BY l.verification_cycle_no, l.line_no'

    rows = db.query(sql, params) or []

    # Step 3: not on any open list - the list is fixed at planning time, so a
    # stranger is rejected and NOTHING is recorded (never insert a line).
    if not rows:
        return {"error": f"Asset {scan_code} is not on any open verification list."}

    # Step 4: ambiguous - the scan cannot decide which cycle the verifier meant.
    cycles = []
    for row in rows:
        cycle = _text(_cell(row, 'verification_cycle_no'))
        if cycle and cycle not in cycles:
            cycles.append(cycle)
    if len(cycles) > 1:
        return {
            "error": (
                f"Asset {scan_code} appears on more than one open verification list "
                f"({', '.join(cycles)}) - open the cycle and use Scan Asset."
            )
        }

    cycle_no = cycles[0]
    asset_name = _text(_cell(rows[0], 'asset_name')) or scan_code

    # Step 5: a finding already recorded by the verifier (DAMAGED / NOT_FOUND /
    # EXTRA_UNREGISTERED - or an earlier FOUND) outranks a later scan.
    target = None
    for row in rows:
        if not _text(_cell(row, 'physical_status_found')):
            target = row
            break
    if target is None:
        existing_status = _text(_cell(rows[0], 'physical_status_found'))
        return {
            "message": (
                f"Asset {scan_code} ({asset_name}) is already recorded as "
                f"{existing_status} on cycle {cycle_no} - nothing was changed."
            )
        }

    chg_user = _text(
        args.get('CHG_USER') or args.get('chg_user')
        or args.get('ADD_USER') or args.get('add_user')
    )

    # Step 6: stamp the planned line as FOUND
    line_values = {
        'physical_status_found': 'FOUND',
        'verified_date': today(),
        'chg_date': now(),
    }
    if chg_user:
        line_values['chg_user'] = chg_user
    db.update(
        'fam_physical_verification_line',
        line_values,
        {
            'verification_cycle_no': cycle_no,
            'line_no': _cell(target, 'line_no'),
        }
    )

    # Step 7: the first scan moves the cycle from PLANNED to IN_PROGRESS
    if _text(_cell(target, 'cycle_status')) == 'PLANNED':
        header_values = {'status': 'IN_PROGRESS', 'chg_date': now()}
        if chg_user:
            header_values['chg_user'] = chg_user
        db.update(
            'fam_physical_verification',
            header_values,
            {'verification_cycle_no': cycle_no}
        )

    # Step 8: confirm, reporting how many lines of the cycle are still unverified
    remaining = db.scalar(
        'SELECT COUNT(*) FROM ' + db.t('fam_physical_verification_line') +
        " WHERE verification_cycle_no = :c AND COALESCE(physical_status_found, '') = ''",
        {'c': cycle_no}
    ) or 0

    return {
        "message": (
            f"Asset {scan_code} ({asset_name}) verified on cycle {cycle_no}. "
            f"{int(remaining)} assets remaining."
        )
    }
