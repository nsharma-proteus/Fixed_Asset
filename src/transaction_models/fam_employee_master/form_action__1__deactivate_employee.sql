/*
project: Fixed_Asset
object_type: T
object_name: fam_employee_master
event_type: form_action
function_name: deactivate_employee
form_no: 1
action_name: Deactivate
language: plpgsql
description: Deactivate the employee and flag their assigned assets for reassignment
functional_specification: UPDATE FAM_EMPLOYEE_MASTER SET STATUS = 'I', CHG_DATE = current timestamp, CHG_USER = current user, CHG_TERM = current terminal WHERE EMPLOYEE_CODE = the payload's EMPLOYEE_CODE. Then, for every row in the Asset Register (FAM_ASSET_REGISTER) whose ASSIGNED_EMPLOYEE_CODE matches this employee, mark/flag it as needing reassignment (e.g. set a REMARKS note or a pending-reassignment indicator) so it surfaces for handling via the Asset Transfer process. Return a confirmation message that the employee was deactivated and how many assets were flagged for reassignment.
business_logic: Deactivate the employee and flag their assigned assets for reassignment
*/

CREATE OR REPLACE FUNCTION deactivate_employee(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_flagged integer;
BEGIN
    -- Deactivate the employee record
    UPDATE FAM_EMPLOYEE_MASTER
    SET STATUS   = 'I',
        CHG_DATE = NOW(),
        CHG_USER = LEFT(CURRENT_USER, 10),
        CHG_TERM = NULL
    WHERE EMPLOYEE_CODE = p->>'EMPLOYEE_CODE';

    -- Flag all assets assigned to this employee for reassignment via Asset Transfer
    UPDATE FAM_ASSET_REGISTER
    SET REMARKS = 'PENDING REASSIGNMENT - Employee ' || p->>'EMPLOYEE_CODE' ||
                  ' deactivated on ' || TO_CHAR(NOW(), 'YYYY-MM-DD')
    WHERE ASSIGNED_EMPLOYEE_CODE = p->>'EMPLOYEE_CODE';

    GET DIAGNOSTICS v_flagged = ROW_COUNT;

    RETURN jsonb_build_object(
        'prompts', jsonb_build_array(
            jsonb_build_object(
                'message',
                'Employee ' || p->>'EMPLOYEE_CODE' || ' (' || p->>'EMPLOYEE_NAME' || ') has been deactivated. ' ||
                v_flagged || ' asset(s) have been flagged for reassignment via the Asset Transfer process.'
            )
        )
    );
END;
$$;
