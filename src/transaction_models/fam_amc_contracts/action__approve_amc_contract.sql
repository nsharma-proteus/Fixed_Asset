/*
project: Fixed_Asset
object_type: T
object_name: fam_amc_contracts
event_type: action
function_name: approve_amc_contract
action_name: Approve
language: plpgsql
description: Approve a Pending Approval AMC contract
functional_specification: Set FAM_AMC_CONTRACTS.STATUS = ACTIVE for this AMC_CONTRACT_NO. For every FAM_AMC_CONTRACT_LINE row under this contract, flag the covered asset's AMC_APPLICABLE = Y (dependency: FAM_ASSET_REGISTER currently only carries ASSET_CODE, ASSET_NAME, CAPITALIZATION_DATE -- it does not yet have an AMC_APPLICABLE column, so this flagging cannot be persisted until that column is added; implement the STATUS update now and add the flagging once the column exists). Return a confirmation message.
business_logic: Approve a Pending Approval AMC contract
*/

CREATE OR REPLACE FUNCTION approve_amc_contract(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_contract_no text;
    v_status      text;
BEGIN
    v_contract_no := p->>'AMC_CONTRACT_NO';
    v_status      := p->>'STATUS';

    -- Only PENDING_APPROVAL contracts may be approved
    IF v_status <> 'PENDING_APPROVAL' THEN
        RETURN jsonb_build_object(
            'error',
            'Only contracts in Pending Approval status can be approved. Current status: ' || v_status || '.'
        );
    END IF;

    -- Activate the contract
    UPDATE fam_amc_contracts
    SET    status = 'ACTIVE'
    WHERE  amc_contract_no = v_contract_no;

    -- NOTE: FAM_ASSET_REGISTER does not yet have an AMC_APPLICABLE column.
    -- Once that column is added, execute:
    --   UPDATE fam_asset_register ar
    --   SET    amc_applicable = 'Y'
    --   FROM   fam_amc_contract_line cl
    --   WHERE  cl.amc_contract_no = v_contract_no
    --     AND  ar.asset_code      = cl.asset_code;

    RETURN jsonb_build_object(
        'message',
        'AMC Contract ' || v_contract_no || ' has been approved and is now Active.'
    );
END;
$$;
