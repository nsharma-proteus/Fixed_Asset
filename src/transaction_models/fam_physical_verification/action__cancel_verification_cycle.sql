/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: action
function_name: cancel_verification_cycle
action_name: Cancel
language: plpgsql
description: Cancel the verification cycle
functional_specification: Set STATUS = 'CANCELLED' and return a confirmation message.
business_logic: Cancel the verification cycle
*/

CREATE OR REPLACE FUNCTION cancel_verification_cycle(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no       text;
    v_current_status text;
BEGIN
    v_cycle_no := p->>'VERIFICATION_CYCLE_NO';

    SELECT STATUS INTO v_current_status
    FROM FAM_PHYSICAL_VERIFICATION
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Verification cycle ' || v_cycle_no || ' not found.');
    END IF;

    IF v_current_status IN ('CLOSED', 'CANCELLED') THEN
        RETURN jsonb_build_object(
            'error', 'Verification cycle is already ' || v_current_status || ' and cannot be cancelled.'
        );
    END IF;

    UPDATE FAM_PHYSICAL_VERIFICATION
    SET STATUS = 'CANCELLED'
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no;

    RETURN jsonb_build_object(
        'message', 'Verification cycle ' || v_cycle_no || ' has been cancelled.'
    );
END;
$$;
