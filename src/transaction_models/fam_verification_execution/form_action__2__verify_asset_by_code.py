# project: Fixed_Asset
# object_type: T
# object_name: fam_verification_execution
# event_type: form_action
# function_name: verify_asset_by_code
# form_no: 2
# action_name: Scan Asset By Code
# language: python
# description: Check a typed asset code against this line's asset and fill it in as Found
# functional_specification: Row action on a Verified Assets line. The runtime asks the user to type the asset code first (capture.field ENTERED_ASSET_CODE) and posts it with the line FLAT (VERIFICATION_CYCLE_NO, ASSET_CODE, PHYSICAL_STATUS_FOUND, VERIFIED_DATE; also lowercase keys). Steps: (1) Empty code -> error. (2) Read the cycle from FAM_PHYSICAL_VERIFICATION; not found or STATUS not PLANNED/IN_PROGRESS -> error. (3) The trimmed code must equal this line's ASSET_CODE (case-insensitive); otherwise error naming both codes. (4) A line already recorded as another status (NOT_FOUND / DAMAGED / EXTRA_UNREGISTERED) is left unchanged with a prompt. (5) Otherwise return updates PHYSICAL_STATUS_FOUND = FOUND and VERIFIED_DATE = today, plus a prompt. Writes nothing - the user saves the record.
# business_logic: Check a typed asset code against this line's asset and fill it in as Found


def _arg(args, name):
    return args.get(name) if args.get(name) is not None else args.get(name.lower())


def run(args):
    entered = str(_arg(args, 'ENTERED_ASSET_CODE') or '').strip()
    if not entered:
        return {"error": "Enter the asset code."}

    cycle_no = str(_arg(args, 'VERIFICATION_CYCLE_NO') or '').strip()
    asset_code = str(_arg(args, 'ASSET_CODE') or '').strip()
    if not cycle_no or not asset_code:
        return {"error": "Open a saved asset line of a verification cycle before entering a code."}

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

    if entered.upper() != asset_code.upper():
        return {"error": f"The code {entered} does not match asset {asset_code} on this line."}

    asset_name = _arg(args, 'ASSET_NAME') or asset_code
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
