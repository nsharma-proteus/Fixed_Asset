/*
project: Fixed_Asset
object_type: T
object_name: fam_department_master
event_type: form_action_validation
function_name: check_department_unused
form_no: 1
action_name: delete
language: plpgsql
description: Block delete when the department is referenced by any asset or employee
functional_specification: Given the current row's BRANCH_CODE and DEPARTMENT_CODE, check whether any row exists in the Asset Register (FAM_ASSET_REGISTER) or the Employee Master (FAM_EMPLOYEE_MASTER) with matching BRANCH_CODE and DEPARTMENT_CODE. If at least one such reference exists, return an error so the delete is blocked; otherwise return NULL/no error to allow the delete to proceed.
business_logic: Block delete when the department is referenced by any asset or employee
*/

CREATE OR REPLACE FUNCTION check_department_unused(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_branch_code  text := p->>'BRANCH_CODE';
    v_dept_code    text := p->>'DEPARTMENT_CODE';
    v_asset_count  integer;
    v_emp_count    integer;
BEGIN
    -- Check Asset Register for any reference to this department
    SELECT COUNT(*) INTO v_asset_count
    FROM fam_asset_register
    WHERE branch_code     = v_branch_code
      AND department_code = v_dept_code;

    -- Check Employee Master for any reference to this department
    SELECT COUNT(*) INTO v_emp_count
    FROM fam_employee_master
    WHERE branch_code     = v_branch_code
      AND department_code = v_dept_code;

    IF v_asset_count > 0 OR v_emp_count > 0 THEN
        RETURN jsonb_build_object(
            'error',
            'Department ' || v_dept_code || ' cannot be deleted — it is referenced by '
            || CASE
                   WHEN v_asset_count > 0 AND v_emp_count > 0 THEN 'assets and employees'
                   WHEN v_asset_count > 0                     THEN 'assets'
                   ELSE                                            'employees'
               END || '.'
        );
    END IF;

    RETURN NULL;
END;
$$;
