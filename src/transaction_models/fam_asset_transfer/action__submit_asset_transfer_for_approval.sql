/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_transfer
event_type: action
function_name: submit_asset_transfer_for_approval
action_name: Submit for Approval
language: plpgsql
description: Move a Draft transfer to Pending Approval
functional_specification: Set STATUS to PENDING_APPROVAL on this transfer record and return a confirmation message.
business_logic: Move a Draft transfer to Pending Approval
*/

CREATE OR REPLACE FUNCTION submit_asset_transfer_for_approval(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_rows integer;
BEGIN
    -- Guard: only DRAFT transfers may be submitted
    IF p->>'STATUS' <> 'DRAFT' THEN
        RETURN jsonb_build_object('error',
            'Only Draft transfers can be submitted for approval. Current status: ' ||
            COALESCE(p->>'STATUS', ''));
    END IF;

    UPDATE fam_asset_transfer
    SET    status = 'PENDING_APPROVAL'
    WHERE  transfer_no = p->>'TRANSFER_NO'
      AND  status = 'DRAFT';  -- optimistic-lock guard against concurrent updates

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RETURN jsonb_build_object('error',
            'Transfer could not be submitted — it may have been modified by another user. '
            'Please refresh and try again.');
    END IF;

    RETURN jsonb_build_object('message',
        'Transfer ' || COALESCE(p->>'TRANSFER_NO', '') ||
        ' has been submitted for approval.');
END;
$$;
