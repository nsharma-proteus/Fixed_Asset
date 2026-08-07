/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: scan_confirm_asset_line
form_no: 2
action_name: Scan to Confirm
language: plpgsql
description: Confirm an asset by scanning its QR/barcode
functional_specification: Stamp VERIFIED_DATE with today's date and set PHYSICAL_STATUS_FOUND = 'FOUND' for this line (unless already marked Damaged or Extra-Unregistered, which are left as-is). Return {"updates": {"physical_status_found": ..., "verified_date": ...}}.
business_logic: Confirm an asset by scanning its QR/barcode
*/

CREATE OR REPLACE FUNCTION scan_confirm_asset_line(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_current_status text;
BEGIN
    v_current_status := p->>'PHYSICAL_STATUS_FOUND';

    -- Lines already marked Damaged or Extra-Unregistered must not be overwritten by a scan
    IF v_current_status IN ('DAMAGED', 'EXTRA_UNREGISTERED') THEN
        RETURN NULL;
    END IF;

    RETURN jsonb_build_object(
        'updates', jsonb_build_object(
            'physical_status_found', 'FOUND',
            'verified_date',         CURRENT_DATE
        )
    );
END;
$$;
