/*
project: Fixed_Asset
object_type: T
object_name: fam_dep_rate_it_master
event_type: form_action_validation
function_name: check_dep_rate_it_unused
form_no: 1
action_name: Delete
language: plpgsql
description: Block delete if the block rate is referenced elsewhere
functional_specification: Given BLOCK_CODE in the payload, check whether it is referenced by FAM_ASSET_CATEGORY_MASTER.INCOME_TAX_BLOCK_CODE or by any posted Income Tax annual depreciation generation record for that block (only tables that exist in the project at deploy time need to be checked). If any matching reference exists, return an error indicating the block rate is in use and cannot be deleted. Otherwise return no error so the delete proceeds.
business_logic: Block delete if the block rate is referenced elsewhere
*/

CREATE OR REPLACE FUNCTION check_dep_rate_it_unused(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_block_code  TEXT;
    v_in_use      BOOLEAN := FALSE;
BEGIN
    v_block_code := p->>'BLOCK_CODE';

    -- Check 1: referenced by an asset category's Income Tax block assignment
    SELECT EXISTS(
        SELECT 1
        FROM fam_asset_category_master
        WHERE income_tax_block_code = v_block_code
    ) INTO v_in_use;

    IF v_in_use THEN
        RETURN jsonb_build_object(
            'error',
            'Block rate ' || v_block_code || ' is assigned to one or more asset categories and cannot be deleted.'
        );
    END IF;

    -- Check 2: referenced by a posted IT annual depreciation generation record.
    -- Uncomment and adjust the table/column names once that table is registered in the project.
    -- SELECT EXISTS(
    --     SELECT 1
    --     FROM fam_it_dep_generation
    --     WHERE block_code = v_block_code
    --       AND posted = 'Y'
    -- ) INTO v_in_use;
    --
    -- IF v_in_use THEN
    --     RETURN jsonb_build_object(
    --         'error',
    --         'Block rate ' || v_block_code || ' has posted IT depreciation records and cannot be deleted.'
    --     );
    -- END IF;

    -- No references found — allow the delete
    RETURN NULL;
END;
$$;
