/*
project: Fixed_Asset
object_type: T
object_name: fam_amc_contracts
event_type: action
function_name: submit_amc_contract_for_approval
action_name: Submit for Approval
language: plpgsql
description: Submit a Draft AMC contract for approval
functional_specification: Validate the header is in DRAFT status and has at least one covered-asset line, then set FAM_AMC_CONTRACTS.STATUS = PENDING_APPROVAL for this AMC_CONTRACT_NO and return a confirmation message.
business_logic: Submit a Draft AMC contract for approval
*/

CREATE OR REPLACE FUNCTION submit_amc_contract_for_approval(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_contract_no  text;
    v_status       text;
    v_line_count   integer;
BEGIN
    v_contract_no := p->>'AMC_CONTRACT_NO';
    v_status      := p->>'STATUS';

    -- Only DRAFT contracts may be submitted
    IF v_status <> 'DRAFT' THEN
        RETURN jsonb_build_object(
            'error',
            'Only Draft contracts can be submitted for approval. Current status: ' || v_status || '.'
        );
    END IF;

    -- Must have at least one covered-asset line
    SELECT COUNT(*)
    INTO   v_line_count
    FROM   fam_amc_contract_line
    WHERE  amc_contract_no = v_contract_no;

    IF v_line_count = 0 THEN
        RETURN jsonb_build_object(
            'error',
            'At least one covered asset must be added to the contract before it can be submitted for approval.'
        );
    END IF;

    -- Advance status
    UPDATE fam_amc_contracts
    SET    status = 'PENDING_APPROVAL'
    WHERE  amc_contract_no = v_contract_no;

    RETURN jsonb_build_object(
        'message',
        'AMC Contract ' || v_contract_no || ' has been submitted for approval.'
    );
END;
$$;
