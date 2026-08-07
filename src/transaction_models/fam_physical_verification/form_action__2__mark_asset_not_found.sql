/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: mark_asset_not_found
form_no: 2
action_name: Mark Not Found
language: plpgsql
description: Mark this line as Not Found
functional_specification: Set PHYSICAL_STATUS_FOUND = 'NOT_FOUND' and stamp VERIFIED_DATE with today's date for this line. Return {"updates": {"physical_status_found": ..., "verified_date": ...}}.
business_logic: Mark this line as Not Found
*/

CREATE OR REPLACE FUNCTION mark_asset_not_found(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    RETURN jsonb_build_object(
        'updates', jsonb_build_object(
            'physical_status_found', 'NOT_FOUND',
            'verified_date',         CURRENT_DATE
        )
    );
END;
$$;
