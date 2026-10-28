# project: Fixed_Asset
# object_type: T
# object_name: fam_verification_execution
# event_type: form_action
# function_name: verify_asset_by_scan
# form_no: 2
# action_name: Scan Asset
# language: python
# description: Check a scanned QR/barcode against this line's asset and fill it in as Found
# functional_specification: Row action on a Verified Assets line. The runtime asks for a scan first (camera or external scanner, capture.field SCANNED_ASSET_CODE) and posts it with the line FLAT (VERIFICATION_CYCLE_NO, ASSET_CODE, PHYSICAL_STATUS_FOUND, VERIFIED_DATE; also lowercase keys). Steps: (1) Empty scan -> error. (2) Read the cycle from FAM_PHYSICAL_VERIFICATION; not found or STATUS not PLANNED/IN_PROGRESS -> error. (3) The scan matches this line when it equals the asset's stored FAM_ASSET_REGISTER.QR_BARCODE_TAG or, once unwrapped (URL ?ASSET_CODE= / last path segment, ASSET_CODE=<code>, JSON {asset_code}, FAM|<code>|..., FAM-<code>), equals ASSET_CODE (case-insensitive); otherwise error naming both codes. (4) A line already recorded as another status (NOT_FOUND / DAMAGED / EXTRA_UNREGISTERED) is left unchanged with a prompt. (5) Otherwise return updates PHYSICAL_STATUS_FOUND = FOUND and VERIFIED_DATE = today, plus a prompt. Writes nothing - the user saves the record.
# business_logic: Check a scanned QR/barcode against this line's asset and fill it in as Found


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
    scanned = str(_arg(args, 'SCANNED_ASSET_CODE') or '').strip()
    if not scanned:
        return {"error": "Nothing was scanned. Scan the asset's QR code or barcode."}

    cycle_no = str(_arg(args, 'VERIFICATION_CYCLE_NO') or '').strip()
    asset_code = str(_arg(args, 'ASSET_CODE') or '').strip()
    if not cycle_no or not asset_code:
        return {"error": "Open a saved asset line of a verification cycle before scanning."}

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

    asset = db.query_one(
        'SELECT ASSET_NAME, QR_BARCODE_TAG FROM ' + db.t('FAM_ASSET_REGISTER') +
        ' WHERE ASSET_CODE = :a',
        {'a': asset_code}
    ) or {}
    tag = str(asset.get('QR_BARCODE_TAG') or '').strip()
    matches = (asset_code.upper() in _scan_candidates(scanned)
               or (tag and tag.upper() == scanned.upper()))
    if not matches:
        return {"error": f"The scanned code {scanned} does not belong to asset {asset_code} on this line."}

    asset_name = asset.get('ASSET_NAME') or _arg(args, 'ASSET_NAME') or asset_code
    current = str(_arg(args, 'PHYSICAL_STATUS_FOUND') or '').strip()
    if current and current != 'FOUND':
        return {"prompts": [{"message":
            f"Asset {asset_code} ({asset_name}) is already recorded as {current} - left unchanged."}]}

    return {
        "updates": {
            "PHYSICAL_STATUS_FOUND": 'FOUND',
            "VERIFIED_DATE": today().isoformat(),
        },
        "prompts": [{"message": f"Asset {asset_code} ({asset_name}) verified as Found. Save to record it."}],
    }
