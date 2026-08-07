/*
project: Fixed_Asset
object_type: T
object_name: fam_branch_master
event_type: form_action
function_name: deactivate_branch
form_no: 1
action_name: Deactivate
language: plpgsql
description: Deactivate the branch
functional_specification: Set STATUS to 'I' (Inactive) for the current branch record and return {"updates": {"status": "I"}} so the form reflects the change.
business_logic: Deactivate the branch
*/

CREATE OR REPLACE FUNCTION deactivate_branch(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    UPDATE fam_branch_master
    SET    status = 'I'
    WHERE  branch_code = p->>'BRANCH_CODE';

    RETURN jsonb_build_object('updates', jsonb_build_object('status', 'I'));
END;
$$;
