/*
project: Fixed_Asset
object_type: T
object_name: fam_employee_master
event_type: form_action_validation
function_name: check_employee_unused
form_no: 1
action_name: delete
language: plpgsql
description: Block delete when the employee has assets assigned to them
functional_specification: Given the current row's EMPLOYEE_CODE, check whether any row exists in the Asset Register (FAM_ASSET_REGISTER) with ASSIGNED_EMPLOYEE_CODE matching this employee. If at least one such asset exists, return an error so the delete is blocked; otherwise return NULL/no error to allow the delete to proceed.
business_logic: Block delete when the employee has assets assigned to them
*/

CREATE OR REPLACE FUNCTION check_employee_unused(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_count integer;
BEGIN
    SELECT COUNT(*)
    INTO v_asset_count
    FROM FAM_ASSET_REGISTER
    WHERE ASSIGNED_EMPLOYEE_CODE = p->>'EMPLOYEE_CODE';

    IF v_asset_count > 0 THEN
        RETURN jsonb_build_object(
            'error',
            'Cannot delete employee ' || p->>'EMPLOYEE_CODE' || ': ' ||
            v_asset_count || ' asset(s) are currently assigned to this employee. ' ||
            'Reassign or transfer all assets via the Asset Transfer process before deleting.'
        );
    END IF;

    RETURN NULL;
END;
$$;
