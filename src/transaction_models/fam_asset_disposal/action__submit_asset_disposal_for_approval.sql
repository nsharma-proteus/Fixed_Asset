/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_disposal
event_type: action
function_name: submit_asset_disposal_for_approval
action_name: Submit for Approval
language: plpgsql
description: Move a Draft disposal to Pending Approval
functional_specification: Set STATUS to PENDING_APPROVAL on this disposal record and return a confirmation message.
business_logic: Move a Draft disposal to Pending Approval
*/

CREATE OR REPLACE FUNCTION submit_asset_disposal_for_approval(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_disposal_no TEXT;
    v_status      TEXT;
BEGIN
    v_disposal_no := p->>'DISPOSAL_NO';
    v_status      := p->>'STATUS';

    -- Only Draft disposals may be submitted.
    IF v_status <> 'DRAFT' THEN
        RETURN jsonb_build_object('error',
            'Only Draft disposals can be submitted for approval. '
            || 'Current status is ''' || COALESCE(v_status, 'Unknown') || '''.');
    END IF;

    UPDATE FAM_ASSET_DISPOSAL
       SET STATUS   = 'PENDING_APPROVAL',
           CHG_DATE = NOW()
     WHERE DISPOSAL_NO = v_disposal_no;

    RETURN jsonb_build_object('message',
        'Disposal ' || v_disposal_no || ' has been submitted for approval.');
END;
$$;
