/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_register
event_type: action
function_name: submit_asset_register_for_approval
action_name: Submit for Approval
language: plpgsql
description: Move a Draft asset register record to Pending Approval
functional_specification: Only allow when current STATUS = 'DRAFT'; if not, raise a blocking error (severity E) stating the asset must be in Draft status to submit. Otherwise set STATUS = 'PENDING_APPROVAL' and save.
business_logic: Move a Draft asset register record to Pending Approval
*/

CREATE OR REPLACE FUNCTION submit_asset_register_for_approval(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_code text;
    v_status     text;
    v_rows       integer;
BEGIN
    v_asset_code := p->>'ASSET_CODE';
    v_status     := p->>'STATUS';

    -- Guard: only DRAFT assets may be submitted
    IF v_status <> 'DRAFT' THEN
        RETURN jsonb_build_object(
            'error',
            'The asset must be in Draft status to submit. Current status: ' ||
            COALESCE(v_status, '') || '.'
        );
    END IF;

    UPDATE fam_asset_register
    SET    status = 'PENDING_APPROVAL'
    WHERE  asset_code = v_asset_code
      AND  status = 'DRAFT';  -- optimistic-lock guard against concurrent updates

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RETURN jsonb_build_object(
            'error',
            'Asset could not be submitted — it may have been modified by another user. '
            'Please refresh and try again.'
        );
    END IF;

    RETURN jsonb_build_object(
        'message',
        'Asset ' || COALESCE(v_asset_code, '') || ' has been submitted for approval.'
    );
END;
$$;
