/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_installation
event_type: form_action
function_name: submit_installation_for_approval
form_no: 1
action_name: Submit for Approval
language: plpgsql
description: Submit the installation record for approval
functional_specification: Validate that the record's STATUS is PENDING (already enforced by the pre-action validation). This action hands the record to the approval workflow bound to this transaction for routing to an approver; it performs no direct status change of its own here — STATUS remains PENDING until the Approve action is actioned by the approver. Return a confirmation message such as 'Installation record for asset <ASSET_CODE> submitted for approval.'
business_logic: Submit the installation record for approval
*/

CREATE OR REPLACE FUNCTION submit_installation_for_approval(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    -- STATUS=PENDING guard is already enforced by the pre-action validation;
    -- this action purely hands off to the approval workflow — no DML here.

    RETURN jsonb_build_object(
        'message',
        'Installation record for asset ' || COALESCE(p->>'ASSET_CODE', '') ||
        ' submitted for approval.'
    );
END;
$$;
