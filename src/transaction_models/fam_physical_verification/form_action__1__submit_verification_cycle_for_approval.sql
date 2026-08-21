/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: submit_verification_cycle_for_approval
form_no: 1
action_name: Submit for Approval
language: plpgsql
description: Move the cycle to Pending Approval
functional_specification: Set STATUS = 'PENDING_APPROVAL' and return a confirmation message.
business_logic: Move the cycle to Pending Approval
*/

CREATE OR REPLACE FUNCTION submit_verification_cycle_for_approval(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no text := p->>'VERIFICATION_CYCLE_NO';
BEGIN
    UPDATE fam_physical_verification
    SET    status   = 'PENDING_APPROVAL',
           chg_date = NOW()
    WHERE  verification_cycle_no = v_cycle_no;

    RETURN jsonb_build_object(
        'message',
        'Verification cycle ' || v_cycle_no || ' has been submitted for approval.'
    );
END;
$$;
