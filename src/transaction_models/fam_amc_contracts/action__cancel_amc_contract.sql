/*
project: Fixed_Asset
object_type: T
object_name: fam_amc_contracts
event_type: action
function_name: cancel_amc_contract
action_name: Cancel
language: plpgsql
description: Cancel an AMC contract
functional_specification: Set FAM_AMC_CONTRACTS.STATUS = CANCELLED for this AMC_CONTRACT_NO and return a confirmation message.
business_logic: Cancel an AMC contract
*/

CREATE OR REPLACE FUNCTION cancel_amc_contract(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_contract_no text;
    v_status      text;
BEGIN
    v_contract_no := p->>'AMC_CONTRACT_NO';
    v_status      := p->>'STATUS';

    -- Guard against terminal states that cannot be cancelled
    IF v_status = 'CANCELLED' THEN
        RETURN jsonb_build_object('error', 'Contract ' || v_contract_no || ' is already Cancelled.');
    END IF;

    IF v_status = 'RENEWED' THEN
        RETURN jsonb_build_object(
            'error',
            'Contract ' || v_contract_no || ' has already been Renewed and cannot be cancelled. '
            || 'Cancel the new renewal contract instead.'
        );
    END IF;

    -- Cancel the contract
    UPDATE fam_amc_contracts
    SET    status = 'CANCELLED'
    WHERE  amc_contract_no = v_contract_no;

    RETURN jsonb_build_object(
        'message',
        'AMC Contract ' || v_contract_no || ' has been cancelled.'
    );
END;
$$;
