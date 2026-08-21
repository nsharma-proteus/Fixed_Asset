/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action_validation
function_name: check_all_lines_verified
form_no: 1
action_name: Submit for Approval
language: plpgsql
description: Ensure no verification line is left unmarked
functional_specification: Count lines on this VERIFICATION_CYCLE_NO in FAM_PHYSICAL_VERIFICATION_LINE where PHYSICAL_STATUS_FOUND is null or blank; return an error string naming the count if any are found, otherwise return nothing.
business_logic: Ensure no verification line is left unmarked
*/

CREATE OR REPLACE FUNCTION check_all_lines_verified(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no   text    := p->>'VERIFICATION_CYCLE_NO';
    v_unverified integer;
BEGIN
    SELECT COUNT(*)
    INTO   v_unverified
    FROM   fam_physical_verification_line
    WHERE  verification_cycle_no = v_cycle_no
      AND  (physical_status_found IS NULL OR physical_status_found = '');

    IF v_unverified > 0 THEN
        RETURN jsonb_build_object(
            'error',
            v_unverified::text
                || ' verification line(s) have no physical status recorded. '
                || 'Please mark all lines before submitting for approval.'
        );
    END IF;

    RETURN NULL;
END;
$$;
