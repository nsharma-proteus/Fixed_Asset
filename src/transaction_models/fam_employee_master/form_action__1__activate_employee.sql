/*
project: Fixed_Asset
object_type: T
object_name: fam_employee_master
event_type: form_action
function_name: activate_employee
form_no: 1
action_name: Activate
language: plpgsql
description: Activate the employee
functional_specification: UPDATE FAM_EMPLOYEE_MASTER SET STATUS = 'A', CHG_DATE = current timestamp, CHG_USER = current user, CHG_TERM = current terminal WHERE EMPLOYEE_CODE = the payload's EMPLOYEE_CODE. Return a confirmation message that the employee was activated.
business_logic: Activate the employee
*/

CREATE OR REPLACE FUNCTION activate_employee(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    UPDATE FAM_EMPLOYEE_MASTER
    SET STATUS   = 'A',
        CHG_DATE = NOW(),
        CHG_USER = LEFT(CURRENT_USER, 10),
        CHG_TERM = NULL
    WHERE EMPLOYEE_CODE = p->>'EMPLOYEE_CODE';

    RETURN jsonb_build_object(
        'prompts', jsonb_build_array(
            jsonb_build_object(
                'message',
                'Employee ' || p->>'EMPLOYEE_CODE' || ' (' || p->>'EMPLOYEE_NAME' || ') has been activated successfully.'
            )
        )
    );
END;
$$;
