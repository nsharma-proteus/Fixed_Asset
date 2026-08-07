/*
project: Fixed_Asset
object_type: T
object_name: fam_branch_master
event_type: form_action
function_name: activate_branch
form_no: 1
action_name: Activate
language: plpgsql
description: Activate the branch
functional_specification: Set STATUS to 'A' (Active) for the current branch record and return {"updates": {"status": "A"}} so the form reflects the change.
business_logic: Activate the branch
*/

CREATE OR REPLACE FUNCTION activate_branch(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    UPDATE fam_branch_master
    SET    status = 'A'
    WHERE  branch_code = p->>'BRANCH_CODE';

    RETURN jsonb_build_object('updates', jsonb_build_object('status', 'A'));
END;
$$;
