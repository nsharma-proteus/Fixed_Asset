/*
project: Fixed_Asset
object_type: T
object_name: fam_branch_master
event_type: form_action_validation
function_name: check_branch_unused
form_no: 1
action_name: Delete
language: plpgsql
description: Block delete if the branch is referenced elsewhere
functional_specification: Given BRANCH_CODE in the payload, check whether it is referenced in FAM_LOCATION_MASTER.BRANCH_CODE, FAM_DEPARTMENT_MASTER.BRANCH_CODE, FAM_EMPLOYEE_MASTER.BRANCH_CODE, or FAM_ASSET_REGISTER.BRANCH_CODE (only tables that exist in the project at deploy time need to be checked). If any matching row exists in any of these tables, return an error indicating the branch is in use and cannot be deleted. Otherwise return no error so the delete proceeds.
business_logic: Block delete if the branch is referenced elsewhere
*/

CREATE OR REPLACE FUNCTION check_branch_unused(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_branch_code TEXT    := p->>'BRANCH_CODE';
    v_ref_table   TEXT;
    v_exists      BOOLEAN;
BEGIN
    -- Check FAM_LOCATION_MASTER
    SELECT EXISTS(
        SELECT 1 FROM fam_location_master WHERE branch_code = v_branch_code
    ) INTO v_exists;
    IF v_exists THEN
        v_ref_table := 'Location Master';
    END IF;

    -- Check FAM_DEPARTMENT_MASTER
    IF v_ref_table IS NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM fam_department_master WHERE branch_code = v_branch_code
        ) INTO v_exists;
        IF v_exists THEN
            v_ref_table := 'Department Master';
        END IF;
    END IF;

    -- Check FAM_EMPLOYEE_MASTER
    IF v_ref_table IS NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM fam_employee_master WHERE branch_code = v_branch_code
        ) INTO v_exists;
        IF v_exists THEN
            v_ref_table := 'Employee Master';
        END IF;
    END IF;

    -- Check FAM_ASSET_REGISTER
    IF v_ref_table IS NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM fam_asset_register WHERE branch_code = v_branch_code
        ) INTO v_exists;
        IF v_exists THEN
            v_ref_table := 'Asset Register';
        END IF;
    END IF;

    IF v_ref_table IS NOT NULL THEN
        RETURN jsonb_build_object(
            'error',
            'Branch ' || v_branch_code || ' is referenced in ' || v_ref_table || ' and cannot be deleted.'
        );
    END IF;

    RETURN NULL;
END;
$$;
