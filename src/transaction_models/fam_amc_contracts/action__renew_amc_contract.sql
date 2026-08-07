/*
project: Fixed_Asset
object_type: T
object_name: fam_amc_contracts
event_type: action
function_name: renew_amc_contract
action_name: Renew
language: plpgsql
description: Renew an Active or Expired AMC contract into a new contract
functional_specification: Create a new FAM_AMC_CONTRACTS row with AMC_CONTRACT_NO auto-generated, PREVIOUS_CONTRACT_NO = this contract's AMC_CONTRACT_NO, AMC_VENDOR_CODE copied from this contract, STATUS = DRAFT, and START_DATE/END_DATE/CONTRACT_COST left for the user to fill in on the new record. Copy every FAM_AMC_CONTRACT_LINE row (ASSET_CODE, COVERAGE_REMARKS) from this contract onto the new AMC_CONTRACT_NO. Set this contract's STATUS = RENEWED. Return a confirmation message including the new AMC_CONTRACT_NO.
business_logic: Renew an Active or Expired AMC contract into a new contract
*/

CREATE OR REPLACE FUNCTION renew_amc_contract(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_contract_no     text;
    v_status          text;
    v_new_contract_no text;
BEGIN
    v_contract_no := p->>'AMC_CONTRACT_NO';
    v_status      := p->>'STATUS';

    -- Only ACTIVE or EXPIRED contracts may be renewed
    IF v_status NOT IN ('ACTIVE', 'EXPIRED') THEN
        RETURN jsonb_build_object(
            'error',
            'Only Active or Expired contracts can be renewed. Current status: ' || v_status || '.'
        );
    END IF;

    -- Auto-generate a unique contract number: 'AMC' + timestamp to millisecond
    -- YYYYMMDDHH24MISSMS = 17 chars → 'AMC' + 17 = 20 chars (fits VARCHAR(20))
    v_new_contract_no := 'AMC' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
    -- Guard against the (extremely unlikely) same-millisecond collision
    WHILE EXISTS (
        SELECT 1 FROM fam_amc_contracts WHERE amc_contract_no = v_new_contract_no
    ) LOOP
        v_new_contract_no := 'AMC' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
    END LOOP;

    -- Create renewal header in DRAFT status.
    -- START_DATE / END_DATE / CONTRACT_COST are copied from the current contract as
    -- starting defaults; the user must review and update them on the new DRAFT record.
    -- PREVIOUS_CONTRACT_STATUS captures the state of the old contract at renewal time
    -- (ACTIVE or EXPIRED) before it is flipped to RENEWED.
    INSERT INTO fam_amc_contracts (
        amc_contract_no,
        amc_vendor_code,
        start_date,
        end_date,
        contract_cost,
        status,
        previous_contract_no,
        previous_contract_vendor_code,
        previous_contract_status
    )
    SELECT
        v_new_contract_no,
        amc_vendor_code,
        start_date,
        end_date,
        contract_cost,
        'DRAFT',
        amc_contract_no,   -- link back to this contract
        amc_vendor_code,   -- denormalised vendor copy
        v_status           -- the pre-renewal status (ACTIVE / EXPIRED)
    FROM fam_amc_contracts
    WHERE amc_contract_no = v_contract_no;

    -- Copy all covered-asset lines to the new contract, preserving line numbers
    INSERT INTO fam_amc_contract_line (
        amc_contract_no,
        line_no,
        asset_code,
        coverage_remarks
    )
    SELECT
        v_new_contract_no,
        line_no,
        asset_code,
        coverage_remarks
    FROM fam_amc_contract_line
    WHERE amc_contract_no = v_contract_no;

    -- Mark the current contract as RENEWED
    UPDATE fam_amc_contracts
    SET    status = 'RENEWED'
    WHERE  amc_contract_no = v_contract_no;

    RETURN jsonb_build_object(
        'message',
        'AMC Contract ' || v_contract_no || ' has been renewed. '
        || 'New contract ' || v_new_contract_no || ' has been created in Draft status. '
        || 'Please update the Start Date, End Date, and Contract Cost on the new contract.'
    );
END;
$$;
