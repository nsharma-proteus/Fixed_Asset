/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: action
function_name: submit_verification_cycle_for_approval
action_name: Submit for Approval
language: plpgsql
description: Move the cycle to Pending Approval
functional_specification: Set STATUS = 'PENDING_APPROVAL' and return a confirmation message.
business_logic: Move the cycle to Pending Approval
*/

CREATE OR REPLACE FUNCTION submit_verification_cycle_for_approval(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
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

    IF v_current_status NOT IN ('PLANNED', 'IN_PROGRESS') THEN
        RETURN jsonb_build_object(
            'error', 'Only cycles in Planned or In Progress status can be submitted for approval. Current status: ' || v_current_status || '.'
        );
    END IF;

    UPDATE FAM_PHYSICAL_VERIFICATION
    SET STATUS = 'PENDING_APPROVAL'
    WHERE VERIFICATION_CYCLE_NO = v_cycle_no;

    RETURN jsonb_build_object(
        'message', 'Verification cycle ' || v_cycle_no || ' has been submitted for approval.'
    );
END;
$$;
