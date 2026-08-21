# project: Fixed_Asset
# object_type: T
# object_name: fam_verification_execution
# event_type: form_action
# function_name: scan_asset_into_verification
# form_no: 1
# action_name: Scan Asset
# language: python
# description: Validate a scanned asset id against the cycle and stamp the line as FOUND
# functional_specification: Payload is the header form FLAT: VERIFICATION_CYCLE_NO and SCAN_ASSET_CODE (also lowercase keys), plus STATUS. Steps: (1) Trim SCAN_ASSET_CODE; if empty return {"error": "Scan or enter an asset code first."}. (2) Read FAM_PHYSICAL_VERIFICATION for VERIFICATION_CYCLE_NO; if not found return an error; if its STATUS is not PLANNED or IN_PROGRESS return {"error": "Verification cycle <no> is not open for execution (status <status>)."}. (3) Look for a row in FAM_PHYSICAL_VERIFICATION_LINE where VERIFICATION_CYCLE_NO = the cycle AND ASSET_CODE = the scanned code. If NO such line exists, record NOTHING and return {"error": "Asset <code> is not part of verification cycle <no>. The list is fixed at planning time - the entry is rejected."}. (4) On a match, UPDATE that line setting PHYSICAL_STATUS_FOUND = 'FOUND' and VERIFIED_DATE = current date (also stamp CHG_DATE / CHG_USER). (5) If the header STATUS is 'PLANNED', UPDATE FAM_PHYSICAL_VERIFICATION SET STATUS = 'IN_PROGRESS' for that cycle. (6) Return an item_change update payload that clears the scan box and reflects the new header status, e.g. {"updates": {"SCAN_ASSET_CODE": "", "STATUS": "IN_PROGRESS", "message": ...}} - only include STATUS when it actually changed. Never insert a new line.
# business_logic: Validate a scanned asset id against the cycle and stamp the line as FOUND


def _normalize_scan_code(raw):
    # A device scanner may hand over a QR url, a key=value blob or a JSON payload
    # instead of the bare code - reduce any of those to the plain asset code.
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

    return value.strip().upper()


def run(args):
    # Step 1: normalize the scanned value - asset codes are stored upper-case
    scan_code = _normalize_scan_code(args.get('SCAN_ASSET_CODE') or args.get('scan_asset_code'))
    if not scan_code:
        return {"error": "Scan or enter an asset id first."}

    cycle_no = args.get('VERIFICATION_CYCLE_NO') or args.get('verification_cycle_no') or ''

    # Step 2: Read the verification cycle header
    cycle = db.query_one(
        'SELECT VERIFICATION_CYCLE_NO, STATUS FROM ' + db.t('FAM_PHYSICAL_VERIFICATION') +
        ' WHERE VERIFICATION_CYCLE_NO = :c',
        {'c': cycle_no}
    )
    if not cycle:
        return {"error": f"Verification cycle {cycle_no} not found."}

    cycle_status = cycle.get('STATUS') or ''
    if cycle_status not in ('PLANNED', 'IN_PROGRESS'):
        return {"error": f"Verification cycle {cycle_no} is not open for execution (status {cycle_status})."}

    # Step 3: membership check - the list is fixed at planning time, nothing is recorded for a stranger
    line = db.query_one(
        'SELECT l.LINE_NO, l.PHYSICAL_STATUS_FOUND, a.ASSET_NAME FROM ' +
        db.t('FAM_PHYSICAL_VERIFICATION_LINE') + ' l LEFT JOIN ' +
        db.t('FAM_ASSET_REGISTER') + ' a ON a.ASSET_CODE = l.ASSET_CODE' +
        ' WHERE l.VERIFICATION_CYCLE_NO = :c AND l.ASSET_CODE = :a',
        {'c': cycle_no, 'a': scan_code}
    )
    if not line:
        return {
            "error": (
                f"Asset {scan_code} is not part of verification list {cycle_no}. "
                "The list is fixed at planning time - the entry is rejected."
            )
        }

    asset_name = line.get('ASSET_NAME') or scan_code
    existing_status = (line.get('PHYSICAL_STATUS_FOUND') or '').strip()
    chg_user = args.get('chg_user') or args.get('CHG_USER') or args.get('add_user') or ''

    # A finding already recorded by the verifier (DAMAGED / EXTRA_UNREGISTERED / NOT_FOUND) outranks a scan
    if existing_status:
        return {
            "updates": {
                "SCAN_ASSET_CODE": "",
                "message": f"Asset {scan_code} ({asset_name}) is already recorded as {existing_status}.",
            }
        }

    # Step 4: Stamp the line as FOUND with today's date
    db.update(
        'FAM_PHYSICAL_VERIFICATION_LINE',
        {
            'PHYSICAL_STATUS_FOUND': 'FOUND',
            'VERIFIED_DATE': today(),
            'CHG_DATE': now(),
            'CHG_USER': chg_user,
        },
        {'VERIFICATION_CYCLE_NO': cycle_no, 'LINE_NO': line['LINE_NO']}
    )

    # Step 5: Transition header to IN_PROGRESS if it was still PLANNED
    updates = {"SCAN_ASSET_CODE": ""}
    if cycle_status == 'PLANNED':
        db.update(
            'FAM_PHYSICAL_VERIFICATION',
            {'STATUS': 'IN_PROGRESS', 'CHG_DATE': now(), 'CHG_USER': chg_user},
            {'VERIFICATION_CYCLE_NO': cycle_no}
        )
        updates["STATUS"] = 'IN_PROGRESS'

    # Step 6: Confirm, reporting how many lines of the cycle are still unverified
    remaining = db.scalar(
        'SELECT COUNT(*) FROM ' + db.t('FAM_PHYSICAL_VERIFICATION_LINE') +
        " WHERE VERIFICATION_CYCLE_NO = :c AND COALESCE(PHYSICAL_STATUS_FOUND, '') = ''",
        {'c': cycle_no}
    ) or 0

    updates["message"] = f"Asset {scan_code} ({asset_name}) verified. {int(remaining)} assets remaining."
    return {"updates": updates}
