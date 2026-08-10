/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: action
function_name: approve_verification_cycle
action_name: Approve
language: plpgsql
description: Approve the verification cycle and apply findings to the Asset Register
functional_specification: Set STATUS = 'CLOSED'. For every line on this VERIFICATION_CYCLE_NO that carries a VERIFIED_DATE, update FAM_ASSET_REGISTER.LAST_VERIFIED_DATE = VERIFIED_DATE for that ASSET_CODE. For every line with PHYSICAL_STATUS_FOUND = 'NOT_FOUND', update FAM_ASSET_REGISTER.STATUS = 'UNDER_INVESTIGATION' for that ASSET_CODE (dependency: FAM_ASSET_REGISTER does not yet have a STATUS column -- this update must be revisited once that column exists). For every line with PHYSICAL_STATUS_FOUND = 'DAMAGED', raise a follow-up remark flag (e.g. append a standard 'Damage follow-up required' note to REMARKS or create a follow-up task) for maintenance/insurance review. Return a confirmation message. Approved cycle data feeds the Verification Report (R).
business_logic: Approve the verification cycle and apply findings to the Asset Register
*/

CREATE OR REPLACE FUNCTION approve_verification_cycle(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no        text;
    v_current_status  text;
    v_not_found_count integer;
    v_damaged_count   integer;
BEGIN
    v_cycle_no := p->>'VERIFICATION_CYCLE_NO';

    SELECT STATUS INTO v_current_status
    FROM FAM_PHYSICAL_VERIFICATION
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Verification cycle ' || v_cycle_no || ' not found.');
    END IF;

    IF v_current_status <> 'PENDING_APPROVAL' THEN
        RETURN jsonb_build_object(
            'error', 'Only cycles in Pending Approval status can be approved. Current status: ' || v_current_status || '.'
        );
    END IF;

    -- Close the verification cycle
    UPDATE FAM_PHYSICAL_VERIFICATION
    SET STATUS = 'CLOSED'
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no;

    -- Stamp LAST_VERIFIED_DATE on the Asset Register for every line that carries a verification date
    UPDATE FAM_ASSET_REGISTER ar
    SET    LAST_VERIFIED_DATE = vl.VERIFIED_DATE
    FROM   FAM_PHYSICAL_VERIFICATION_LINE vl
    WHERE  vl.VERIFICATION_CYCLE_NO = v_cycle_no
    AND    vl.VERIFIED_DATE IS NOT NULL
    AND    ar.ASSET_CODE = vl.ASSET_CODE;

    -- Count NOT_FOUND lines (used in confirmation message)
    SELECT COUNT(*) INTO v_not_found_count
    FROM FAM_PHYSICAL_VERIFICATION_LINE
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no
    AND PHYSICAL_STATUS_FOUND = 'NOT_FOUND';

    -- NOTE: FAM_ASSET_REGISTER does not yet have a STATUS column.
    -- Once STATUS is added, execute:
    --   UPDATE FAM_ASSET_REGISTER ar
    --   SET    ar.STATUS = 'UNDER_INVESTIGATION'
    --   FROM   FAM_PHYSICAL_VERIFICATION_LINE vl
    --   WHERE  vl.VERIFICATION_CYCLE_NO = v_cycle_no
    --   AND    vl.PHYSICAL_STATUS_FOUND  = 'NOT_FOUND'
    --   AND    ar.ASSET_CODE             = vl.ASSET_CODE;

    -- Append a follow-up remark to every DAMAGED line for maintenance/insurance review
    SELECT COUNT(*) INTO v_damaged_count
    FROM FAM_PHYSICAL_VERIFICATION_LINE
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no
    AND PHYSICAL_STATUS_FOUND = 'DAMAGED';

    IF v_damaged_count > 0 THEN
        UPDATE FAM_PHYSICAL_VERIFICATION_LINE
        SET REMARKS = CASE
                          WHEN REMARKS IS NULL OR REMARKS = ''
                              THEN 'Damage follow-up required'
                          WHEN REMARKS NOT LIKE '%Damage follow-up required%'
                              THEN REMARKS || ' | Damage follow-up required'
                          ELSE REMARKS
                      END
        WHERE VERIFICATION_CYCLE_NO = v_cycle_no
        AND   PHYSICAL_STATUS_FOUND = 'DAMAGED';
    END IF;

    RETURN jsonb_build_object(
        'message', 'Verification cycle ' || v_cycle_no || ' approved and closed. '
                   || v_not_found_count || ' asset(s) flagged for investigation (FAM_ASSET_REGISTER.STATUS update pending column addition); '
                   || v_damaged_count   || ' damaged asset(s) flagged for maintenance/insurance review.'
    );
END;
$$;
