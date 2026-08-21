/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: approve_verification_cycle
form_no: 1
action_name: Approve
language: plpgsql
description: Approve the verification cycle and apply findings to the Asset Register
functional_specification: Set STATUS = 'CLOSED'. For every line on this VERIFICATION_CYCLE_NO with PHYSICAL_STATUS_FOUND = 'NOT_FOUND', update FAM_ASSET_REGISTER.STATUS = 'UNDER_INVESTIGATION' for that ASSET_CODE (dependency: FAM_ASSET_REGISTER does not yet have a STATUS column -- this update must be revisited once that column exists). For every line with PHYSICAL_STATUS_FOUND = 'DAMAGED', raise a follow-up remark flag (e.g. append a standard 'Damage follow-up required' note to REMARKS or create a follow-up task) for maintenance/insurance review. Return a confirmation message. Approved cycle data feeds the Verification Report (R).
business_logic: Approve the verification cycle and apply findings to the Asset Register
*/

CREATE OR REPLACE FUNCTION approve_verification_cycle(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no   text    := p->>'VERIFICATION_CYCLE_NO';
    v_not_found  integer := 0;
    v_damaged    integer := 0;
BEGIN
    -- 1. Close the verification cycle
    UPDATE fam_physical_verification
    SET    status   = 'CLOSED',
           chg_date = NOW()
    WHERE  verification_cycle_no = v_cycle_no;

    -- 2. Mark NOT_FOUND assets as Under Investigation in the Asset Register
    --    STATUS column is confirmed present in FAM_ASSET_REGISTER with value 'UNDER_INVESTIGATION'
    UPDATE fam_asset_register
    SET    status   = 'UNDER_INVESTIGATION',
           chg_date = NOW()
    WHERE  asset_code IN (
               SELECT asset_code
               FROM   fam_physical_verification_line
               WHERE  verification_cycle_no = v_cycle_no
                 AND  physical_status_found = 'NOT_FOUND'
           );

    GET DIAGNOSTICS v_not_found = ROW_COUNT;

    -- 3. Append a damage follow-up remark on DAMAGED assets for maintenance/insurance review
    UPDATE fam_asset_register
    SET    remarks  = CASE
                          WHEN remarks IS NULL OR remarks = ''
                          THEN 'Damage follow-up required'
                          ELSE LEFT(remarks || '; Damage follow-up required', 500)
                      END,
           chg_date = NOW()
    WHERE  asset_code IN (
               SELECT asset_code
               FROM   fam_physical_verification_line
               WHERE  verification_cycle_no = v_cycle_no
                 AND  physical_status_found = 'DAMAGED'
           );

    GET DIAGNOSTICS v_damaged = ROW_COUNT;

    -- 4. Update LAST_VERIFIED_DATE on the Asset Register for all verified lines
    UPDATE fam_asset_register ar
    SET    last_verified_date = sub.max_verified,
           chg_date           = NOW()
    FROM  (
        SELECT   asset_code,
                 MAX(verified_date) AS max_verified
        FROM     fam_physical_verification_line
        WHERE    verification_cycle_no = v_cycle_no
          AND    verified_date         IS NOT NULL
        GROUP BY asset_code
    ) sub
    WHERE  ar.asset_code = sub.asset_code;

    RETURN jsonb_build_object(
        'message',
        'Verification cycle ' || v_cycle_no || ' approved and closed. '
            || v_not_found::text || ' asset(s) flagged as Under Investigation; '
            || v_damaged::text   || ' asset(s) flagged for damage follow-up.'
    );
END;
$$;
