/*
project: Fixed_Asset
object_type: T
object_name: fam_location_master
event_type: form_action_validation
function_name: check_location_unused
form_no: 1
action_name: delete
language: plpgsql
description: Block delete when the location is referenced by any asset
functional_specification: Given the current row's BRANCH_CODE and LOCATION_CODE, check whether any row exists in the Asset Register (FAM_ASSET_REGISTER) with matching BRANCH_CODE and LOCATION_CODE. If at least one such asset exists, return an error so the delete is blocked; otherwise return NULL/no error to allow the delete to proceed.
business_logic: Block delete when the location is referenced by any asset
*/

CREATE OR REPLACE FUNCTION check_location_unused(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_count integer;
BEGIN
    -- Block delete if any asset in the register references this branch + location
    SELECT COUNT(*)
    INTO   v_asset_count
    FROM   fam_asset_register
    WHERE  branch_code   = p->>'BRANCH_CODE'
      AND  location_code = p->>'LOCATION_CODE';

    IF v_asset_count > 0 THEN
        RETURN jsonb_build_object(
            'error',
            'Cannot delete location ' || p->>'LOCATION_CODE' ||
            ': it is referenced by ' || v_asset_count || ' asset record(s). ' ||
            'Reassign or retire those assets before deleting this location.'
        );
    END IF;

    RETURN NULL;
END;
$$;
