/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_disposal
event_type: action
function_name: cancel_asset_disposal
action_name: Cancel
language: plpgsql
description: Cancel a Draft or Pending Approval disposal
functional_specification: Set STATUS to CANCELLED on this disposal record and return a confirmation message. Approved disposals cannot be cancelled since the Asset Register has already been marked Disposed.
business_logic: Cancel a Draft or Pending Approval disposal
*/

CREATE OR REPLACE FUNCTION cancel_asset_disposal(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_disposal_no TEXT;
    v_status      TEXT;
BEGIN
    v_disposal_no := p->>'DISPOSAL_NO';
    v_status      := p->>'STATUS';

    -- Approved disposals have already marked the asset as Disposed in the Asset
    -- Register; reversing that is a separate reinstatement workflow, not a cancel.
    IF v_status = 'APPROVED' THEN
        RETURN jsonb_build_object('error',
            'Approved disposals cannot be cancelled because the Asset Register '
            || 'has already been marked Disposed. Raise a reinstatement request instead.');
    END IF;

    -- Already-cancelled disposals need no action.
    IF v_status = 'CANCELLED' THEN
        RETURN jsonb_build_object('error',
            'Disposal ' || v_disposal_no || ' is already cancelled.');
    END IF;

    -- Accept DRAFT and PENDING_APPROVAL statuses.
    IF v_status NOT IN ('DRAFT', 'PENDING_APPROVAL') THEN
        RETURN jsonb_build_object('error',
            'Cannot cancel a disposal with status ''' || COALESCE(v_status, 'Unknown') || '''.');
    END IF;

    UPDATE FAM_ASSET_DISPOSAL
       SET STATUS   = 'CANCELLED',
           CHG_DATE = NOW()
     WHERE DISPOSAL_NO = v_disposal_no;

    RETURN jsonb_build_object('message',
        'Disposal ' || v_disposal_no || ' has been cancelled.');
END;
$$;
