/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_transfer
event_type: action
function_name: cancel_asset_transfer
action_name: Cancel
language: plpgsql
description: Cancel a Draft or Pending Approval transfer
functional_specification: Set STATUS to CANCELLED on this transfer record and return a confirmation message. Approved transfers cannot be cancelled since the Asset Register has already been updated by the approval.
business_logic: Cancel a Draft or Pending Approval transfer
*/

CREATE OR REPLACE FUNCTION cancel_asset_transfer(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_rows integer;
BEGIN
    -- Approved transfers are permanently committed — Asset Register already updated
    IF p->>'STATUS' = 'APPROVED' THEN
        RETURN jsonb_build_object('error',
            'Approved transfers cannot be cancelled — the Asset Register has already been '
            'updated. Raise a reverse transfer to undo the movement.');
    END IF;

    IF p->>'STATUS' = 'CANCELLED' THEN
        RETURN jsonb_build_object('error', 'This transfer is already cancelled.');
    END IF;

    UPDATE fam_asset_transfer
    SET    status = 'CANCELLED'
    WHERE  transfer_no = p->>'TRANSFER_NO'
      AND  status IN ('DRAFT', 'PENDING_APPROVAL');  -- optimistic-lock guard

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RETURN jsonb_build_object('error',
            'Transfer could not be cancelled — it may have been modified by another user. '
            'Please refresh and try again.');
    END IF;

    RETURN jsonb_build_object('message',
        'Transfer ' || COALESCE(p->>'TRANSFER_NO', '') || ' has been cancelled.');
END;
$$;
