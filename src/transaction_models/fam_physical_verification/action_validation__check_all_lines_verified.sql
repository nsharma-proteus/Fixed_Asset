/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: action_validation
function_name: check_all_lines_verified
action_name: Submit for Approval
language: plpgsql
description: Ensure no verification line is left unmarked
functional_specification: Count lines on this VERIFICATION_CYCLE_NO in FAM_PHYSICAL_VERIFICATION_LINE where PHYSICAL_STATUS_FOUND is null or blank; return an error string naming the count if any are found, otherwise return nothing.
business_logic: Ensure no verification line is left unmarked
*/

CREATE OR REPLACE FUNCTION check_all_lines_verified(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no   text;
    v_unverified integer;
BEGIN
    v_cycle_no := p->>'VERIFICATION_CYCLE_NO';

    SELECT COUNT(*) INTO v_unverified
    FROM FAM_PHYSICAL_VERIFICATION_LINE
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no
    AND (PHYSICAL_STATUS_FOUND IS NULL OR PHYSICAL_STATUS_FOUND = '');

    IF v_unverified > 0 THEN
        RETURN jsonb_build_object(
            'error', v_unverified || ' verification line(s) have no status recorded. '
                     || 'Mark all assets as Found, Not Found, Damaged, or Extra-Unregistered before submitting.'
        );
    END IF;

    RETURN NULL;
END;
$$;
