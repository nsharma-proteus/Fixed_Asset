/*
project: Fixed_Asset
object_type: T
object_name: fam_dep_rate_ca_master
event_type: form_action_validation
function_name: check_dep_rate_ca_unused
form_no: 1
action_name: Delete
language: plpgsql
description: Block delete if the rate is referenced elsewhere
functional_specification: Given CATEGORY_CODE in the payload, check whether it is referenced by FAM_ASSET_CATEGORY_MASTER.CATEGORY_CODE or by any posted Companies Act monthly depreciation generation record for that category (only tables that exist in the project at deploy time need to be checked). If any matching reference exists, return an error indicating the rate is in use and cannot be deleted. Otherwise return no error so the delete proceeds.
business_logic: Block delete if the rate is referenced elsewhere
*/

CREATE OR REPLACE FUNCTION check_dep_rate_ca_unused(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_category_code text := p->>'CATEGORY_CODE';
    v_ref_count     integer;
BEGIN
    -- Check if any asset category references this depreciation rate
    SELECT COUNT(*) INTO v_ref_count
    FROM fam_asset_category_master
    WHERE category_code = v_category_code;

    IF v_ref_count > 0 THEN
        RETURN jsonb_build_object(
            'error', 'Depreciation rate "' || v_category_code || '" is referenced by one or more asset categories and cannot be deleted.'
        );
    END IF;

    RETURN NULL;
END;
$$;
