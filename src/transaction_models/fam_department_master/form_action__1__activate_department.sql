/*
project: Fixed_Asset
object_type: T
object_name: fam_department_master
event_type: form_action
function_name: activate_department
form_no: 1
action_name: Activate
language: plpgsql
description: Activate the department
functional_specification: UPDATE FAM_DEPARTMENT_MASTER SET STATUS = 'A', CHG_DATE = current timestamp, CHG_USER = current user, CHG_TERM = current terminal WHERE BRANCH_CODE = the payload's BRANCH_CODE and DEPARTMENT_CODE = the payload's DEPARTMENT_CODE. Return a confirmation message that the department was activated.
business_logic: Activate the department
*/

CREATE OR REPLACE FUNCTION activate_department(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    UPDATE fam_department_master
    SET    status   = 'A',
           chg_date = now(),
           chg_user = p->>'CHG_USER',
           chg_term = p->>'CHG_TERM'
    WHERE  branch_code     = p->>'BRANCH_CODE'
      AND  department_code = p->>'DEPARTMENT_CODE';

    RETURN jsonb_build_object(
        'message',
        'Department ' || COALESCE(p->>'DEPARTMENT_CODE', '') || ' has been activated successfully.'
    );
END;
$$;
