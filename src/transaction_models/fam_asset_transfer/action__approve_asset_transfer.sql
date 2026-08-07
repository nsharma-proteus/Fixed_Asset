/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_transfer
event_type: action
function_name: approve_asset_transfer
action_name: Approve
language: plpgsql
description: Approve the transfer and update the Asset Register's current location/custody
functional_specification: Set STATUS to APPROVED on this transfer record. Then UPDATE the Asset Register row for ASSET_CODE, setting its current BRANCH_CODE/LOCATION_CODE/DEPARTMENT_CODE/ASSIGNED_EMPLOYEE_CODE to this record's to_branch_code/to_location_code/to_department_code/to_employee_code. This FAM_ASSET_TRANSFER row itself remains as the permanent audit trail of the movement (no separate history table needed). Return a confirmation message. Depends on FAM_ASSET_REGISTER carrying BRANCH_CODE/LOCATION_CODE/DEPARTMENT_CODE/ASSIGNED_EMPLOYEE_CODE columns.
business_logic: Approve the transfer and update the Asset Register's current location/custody
*/

-- SCHEMA DEPENDENCY: FAM_ASSET_REGISTER must have BRANCH_CODE, LOCATION_CODE,
-- DEPARTMENT_CODE, ASSIGNED_EMPLOYEE_CODE columns added by the Asset Register
-- object before this function can be deployed.

CREATE OR REPLACE FUNCTION approve_asset_transfer(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_rows integer;
BEGIN
    -- Guard: only Pending Approval transfers may be approved
    IF p->>'STATUS' <> 'PENDING_APPROVAL' THEN
        RETURN jsonb_build_object('error',
            'Only transfers in Pending Approval status can be approved. Current status: ' ||
            COALESCE(p->>'STATUS', ''));
    END IF;

    -- Approve the transfer; optimistic-lock guards against concurrent state change
    UPDATE fam_asset_transfer
    SET    status = 'APPROVED'
    WHERE  transfer_no = p->>'TRANSFER_NO'
      AND  status = 'PENDING_APPROVAL';

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RETURN jsonb_build_object('error',
            'Transfer could not be approved — it may have been modified by another user. '
            'Please refresh and try again.');
    END IF;

    -- Advance the asset's live location/custody in the Asset Register.
    -- The FAM_ASSET_TRANSFER row itself is the permanent movement audit trail.
    UPDATE fam_asset_register
    SET    branch_code             = p->>'TO_BRANCH_CODE',
           location_code           = p->>'TO_LOCATION_CODE',
           department_code         = p->>'TO_DEPARTMENT_CODE',
           assigned_employee_code  = p->>'TO_EMPLOYEE_CODE'
    WHERE  asset_code = p->>'ASSET_CODE';

    RETURN jsonb_build_object('message',
        'Transfer ' || COALESCE(p->>'TRANSFER_NO', '') ||
        ' has been approved. Asset ' || COALESCE(p->>'ASSET_CODE', '') ||
        ' is now at ' ||
        COALESCE(p->>'TO_LOCATION_NAME', p->>'TO_LOCATION_CODE', 'the new location') || '.');
END;
$$;
