# project: Fixed_Asset
# object_type: T
# object_name: fam_verification_execution
# event_type: form_action
# function_name: match_scanned_asset
# form_no: 2
# action_name: Start Scanning
# language: python
# description: Find the verification line a scanned QR/barcode belongs to and answer it filled in as Found
# functional_specification: Scan session on the Verified Assets lines (capture loop, field SCANNED_ASSET_CODE, match ASSET_CODE). Payload: SCANNED_ASSET_CODE plus the parent key VERIFICATION_CYCLE_NO (also lowercase keys). Steps: (1) Empty scan -> error. (2) Read the cycle from FAM_PHYSICAL_VERIFICATION; not found or STATUS not PLANNED/IN_PROGRESS -> error. (3) Find the line of this cycle whose asset matches the scan: the scan equals the asset's FAM_ASSET_REGISTER.QR_BARCODE_TAG, or, once unwrapped (URL ?ASSET_CODE= / last path segment, ASSET_CODE=<code>, JSON {asset_code}, FAM|<code>|..., FAM-<code>), equals ASSET_CODE (case-insensitive). None -> error "Asset <code> is not in the current asset list of cycle <no>." (4) A line already recorded (any PHYSICAL_STATUS_FOUND) -> error naming that status and its verified date. (5) Otherwise return a ONE-ROW list for the line: ASSET_CODE, ASSET_NAME, the asset details (category, serial no, make, model, asset status), PHYSICAL_STATUS_FOUND = FOUND and VERIFIED_DATE = today. Writes nothing - the user confirms on screen and saves the record.
# business_logic: Find the verification line a scanned QR/barcode belongs to and answer it filled in as Found


def _arg(args, name):
    return args.get(name) if args.get(name) is not None else args.get(name.lower())


def _scan_candidates(raw):
    # Every reading of a scanned label that could be the bare asset code: the
    # text itself, and the code inside a URL / key=value / JSON / FAM tag.
    value = re.sub(r'[\x00-\x1f\x7f]', '', str(raw or '')).strip()
    out = {value}
    if '://' in value or value.lower().startswith('http'):
        path = value.split('#', 1)[0]
        query = ''
        if '?' in path:
            path, query = path.split('?', 1)
        for pair in query.split('&'):
            key, sep, val = pair.partition('=')
            if sep and key.strip().upper() == 'ASSET_CODE':
                out.add(val.strip())
        segments = [s for s in path.split('/') if s.strip()]
        if segments:
            out.add(segments[-1].strip())
    if 'ASSET_CODE=' in value.upper():
        tail = value[value.upper().index('ASSET_CODE=') + len('ASSET_CODE='):]
        out.add(re.split(r'[&;,\s]', tail)[0].strip())
    if value.startswith('{'):
        try:
            parsed = json.loads(value)
        except Exception:
            parsed = None
        if isinstance(parsed, dict):
            out.add(str(parsed.get('ASSET_CODE') or parsed.get('asset_code') or '').strip())
    for v in list(out):
        if v.upper().startswith('FAM|'):
            out.add(v.split('|')[1].strip() if len(v.split('|')) > 1 else '')
        elif v.upper().startswith('FAM-'):
            out.add(v[4:].strip())
    return {v.upper() for v in out if v}


def run(args):
    scanned = re.sub(r'[\x00-\x1f\x7f]', '', str(_arg(args, 'SCANNED_ASSET_CODE') or '')).strip()
    if not scanned:
        return {"error": "Nothing was scanned."}

    cycle_no = str(_arg(args, 'VERIFICATION_CYCLE_NO') or '').strip()
    if not cycle_no:
        return {"error": "Save the verification cycle before scanning."}

    cycle = db.query_one(
        'SELECT STATUS FROM ' + db.t('FAM_PHYSICAL_VERIFICATION') +
        ' WHERE VERIFICATION_CYCLE_NO = :c',
        {'c': cycle_no}
    )
    if not cycle:
        return {"error": f"Verification cycle {cycle_no} not found."}
    status = (cycle.get('STATUS') or '').strip()
    if status not in ('PLANNED', 'IN_PROGRESS'):
        return {"error": f"Verification cycle {cycle_no} is not open for execution (status {status})."}

    lines = db.query(
        'SELECT l.ASSET_CODE, l.PHYSICAL_STATUS_FOUND, l.VERIFIED_DATE, a.ASSET_NAME, a.QR_BARCODE_TAG,'
        ' a.CATEGORY_CODE, a.SERIAL_NO, a.MAKE, a.MODEL, a.STATUS AS ASSET_STATUS FROM ' +
        db.t('FAM_PHYSICAL_VERIFICATION_LINE') + ' l LEFT JOIN ' + db.t('FAM_ASSET_REGISTER') +
        ' a ON a.ASSET_CODE = l.ASSET_CODE WHERE l.VERIFICATION_CYCLE_NO = :c',
        {'c': cycle_no}
    ) or []
    candidates = _scan_candidates(scanned)
    line = None
    for r in lines:
        if (str(r.get('ASSET_CODE') or '').strip().upper() in candidates
                or str(r.get('QR_BARCODE_TAG') or '').strip().upper() == scanned.upper()):
            line = r
            break
    if not line:
        return {"error": f"Asset {scanned} is not in the current asset list of cycle {cycle_no}."}

    asset_code = str(line.get('ASSET_CODE') or '').strip()
    recorded = str(line.get('PHYSICAL_STATUS_FOUND') or '').strip()
    if recorded:
        when = line.get('VERIFIED_DATE')
        on = f" on {when}" if when else ''
        return {"error": f"Asset {asset_code} is already recorded as {recorded}{on}."}

    return [{
        "ASSET_CODE": asset_code,
        "ASSET_NAME": line.get('ASSET_NAME') or '',
        "asset_category_code": line.get('CATEGORY_CODE') or '',
        "asset_serial_no": line.get('SERIAL_NO') or '',
        "asset_make": line.get('MAKE') or '',
        "asset_model": line.get('MODEL') or '',
        "asset_status": line.get('ASSET_STATUS') or '',
        "PHYSICAL_STATUS_FOUND": 'FOUND',
        "VERIFIED_DATE": today().isoformat(),
    }]
