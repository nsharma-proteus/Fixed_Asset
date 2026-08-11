/*
project: Fixed_Asset
object_type: T
object_name: fam_amc_contracts
event_type: action
function_name: expire_amc_contract
action_name: Expire
language: plpgsql
description: Mark an Active AMC contract Expired once its end date has passed
functional_specification: Set FAM_AMC_CONTRACTS.STATUS = EXPIRED for this AMC_CONTRACT_NO and return a confirmation message.
business_logic: Mark an Active AMC contract Expired once its end date has passed
*/

CREATE OR REPLACE FUNCTION expire_amc_contract(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_contract_no text;
    v_status      text;
BEGIN
    v_contract_no := p->>'AMC_CONTRACT_NO';
    v_status      := p->>'STATUS';

    -- Guard against a contract that is already Expired
    IF v_status = 'EXPIRED' THEN
        RETURN jsonb_build_object('error', 'Contract ' || v_contract_no || ' is already Expired.');
    END IF;

    -- Expire the contract
    UPDATE fam_amc_contracts
    SET    status = 'EXPIRED'
    WHERE  amc_contract_no = v_contract_no;

    RETURN jsonb_build_object(
        'message',
        'AMC Contract ' || v_contract_no || ' has been marked Expired.'
    );
END;
$$;
