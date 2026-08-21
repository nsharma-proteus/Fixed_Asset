/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: cancel_verification_cycle
form_no: 1
action_name: Cancel
language: plpgsql
description: Cancel the verification cycle
functional_specification: Set STATUS = 'CANCELLED' and return a confirmation message.
business_logic: Cancel the verification cycle
*/

CREATE OR REPLACE FUNCTION cancel_verification_cycle(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no text := p->>'VERIFICATION_CYCLE_NO';
BEGIN
    UPDATE fam_physical_verification
    SET    status   = 'CANCELLED',
           chg_date = NOW()
    WHERE  verification_cycle_no = v_cycle_no;

    RETURN jsonb_build_object(
        'message',
        'Verification cycle ' || v_cycle_no || ' has been cancelled.'
    );
END;
$$;
