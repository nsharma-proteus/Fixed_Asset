/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: mark_asset_damaged
form_no: 2
action_name: Mark Damaged
language: plpgsql
description: Mark this line as Damaged
functional_specification: Set PHYSICAL_STATUS_FOUND = 'DAMAGED' and stamp VERIFIED_DATE with today's date for this line. Return {"updates": {"physical_status_found": ..., "verified_date": ...}}.
business_logic: Mark this line as Damaged
*/

CREATE OR REPLACE FUNCTION mark_asset_damaged(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    RETURN jsonb_build_object(
        'updates', jsonb_build_object(
            'physical_status_found', 'DAMAGED',
            'verified_date',         CURRENT_DATE
        )
    );
END;
$$;
