/*
project: Fixed_Asset
object_type: T
object_name: fam_location_master
event_type: form_action
function_name: activate_location
form_no: 1
action_name: Activate
language: plpgsql
description: Activate the location
functional_specification: UPDATE FAM_LOCATION_MASTER SET STATUS = 'A', CHG_DATE = current timestamp, CHG_USER = current user, CHG_TERM = current terminal WHERE BRANCH_CODE = the payload's BRANCH_CODE and LOCATION_CODE = the payload's LOCATION_CODE. Return a confirmation message that the location was activated.
business_logic: Activate the location
*/

CREATE OR REPLACE FUNCTION activate_location(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    UPDATE fam_location_master
    SET    status   = 'A',
           chg_date = CURRENT_TIMESTAMP,
           chg_user = p->>'CHG_USER',
           chg_term = p->>'CHG_TERM'
    WHERE  branch_code   = p->>'BRANCH_CODE'
      AND  location_code = p->>'LOCATION_CODE';

    RETURN jsonb_build_object(
        'prompts', jsonb_build_array(
            jsonb_build_object(
                'message',
                'Location ' || p->>'LOCATION_CODE' || ' has been activated successfully.'
            )
        )
    );
END;
$$;
