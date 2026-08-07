/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_installation
event_type: form_action
function_name: cancel_installation
form_no: 1
action_name: Cancel
language: plpgsql
description: Cancel the installation record
functional_specification: Validate that the record's STATUS is PENDING (already enforced by the pre-action validation — a Confirmed record represents an asset already put to use and cannot be cancelled). UPDATE FAM_ASSET_INSTALLATION SET STATUS = 'CANCELLED', CHG_DATE = current timestamp, CHG_USER = current user, CHG_TERM = current terminal WHERE ID = the payload's id. Return a confirmation message that the installation record was cancelled.
business_logic: Cancel the installation record
*/

CREATE OR REPLACE FUNCTION cancel_installation(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    -- STATUS=PENDING guard is already enforced by the pre-action validation;
    -- CONFIRMED records (asset already put to use) are excluded at that layer.

    UPDATE fam_asset_installation
    SET    status   = 'CANCELLED',
           chg_date = CURRENT_TIMESTAMP,
           chg_user = p->>'CHG_USER',
           chg_term = p->>'CHG_TERM'
    WHERE  id = (p->>'ID')::numeric;

    RETURN jsonb_build_object(
        'message',
        'Installation record for asset ' || COALESCE(p->>'ASSET_CODE', '') ||
        ' has been cancelled.'
    );
END;
$$;
