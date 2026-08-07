/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_transfer
event_type: form_validation
function_name: verify_from_matches_current_location
form_no: 1
language: plpgsql
description: Ensure from_* values still match the asset's current location before save
functional_specification: On add (and on edit while status is still DRAFT), re-fetch the asset's current BRANCH_CODE, LOCATION_CODE, DEPARTMENT_CODE and ASSIGNED_EMPLOYEE_CODE from the Asset Register for ASSET_CODE and compare them to from_branch_code/from_location_code/from_department_code/from_employee_code on this record; return an error ({"error":"..."}) if any differ. Skip the check when _action = 'edit' and the stored status is no longer DRAFT (already-submitted/approved records are immutable history). Depends on FAM_ASSET_REGISTER carrying BRANCH_CODE/LOCATION_CODE/DEPARTMENT_CODE/ASSIGNED_EMPLOYEE_CODE columns (see the fill_asset_current_location item_change function).
business_logic: Ensure from_* values still match the asset's current location before save
*/

-- SCHEMA DEPENDENCY: FAM_ASSET_REGISTER must have BRANCH_CODE, LOCATION_CODE,
-- DEPARTMENT_CODE, ASSIGNED_EMPLOYEE_CODE columns added by the Asset Register
-- object before this function can be deployed.

CREATE OR REPLACE FUNCTION verify_from_matches_current_location(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_reg_branch     text;
    v_reg_location   text;
    v_reg_department text;
    v_reg_employee   text;
BEGIN
    -- On edit, skip entirely when the record is no longer DRAFT
    -- (submitted/approved records are immutable history — the from_* fields
    --  were correct at submission time and cannot be retroactively challenged)
    IF p->>'_action' = 'edit' AND COALESCE(p->>'STATUS', '') <> 'DRAFT' THEN
        RETURN NULL;
    END IF;

    -- Re-fetch the asset's live location from the Asset Register
    SELECT branch_code,
           location_code,
           department_code,
           assigned_employee_code
    INTO   v_reg_branch, v_reg_location, v_reg_department, v_reg_employee
    FROM   fam_asset_register
    WHERE  asset_code = p->>'ASSET_CODE';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error',
            'Asset ' || COALESCE(p->>'ASSET_CODE', '') ||
            ' was not found in the Asset Register.');
    END IF;

    -- btrim applied to the fetched variable (VARCHAR column, but defensive),
    -- NOT to the column itself — preserves index use on the WHERE above.

    IF COALESCE(btrim(v_reg_branch), '') <> COALESCE(p->>'FROM_BRANCH_CODE', '') THEN
        RETURN jsonb_build_object('error',
            'From Branch (' || COALESCE(p->>'FROM_BRANCH_CODE', 'blank') ||
            ') no longer matches the asset''s current branch (' ||
            COALESCE(btrim(v_reg_branch), 'blank') ||
            '). Re-select the asset code to reload current location details.');
    END IF;

    IF COALESCE(btrim(v_reg_location), '') <> COALESCE(p->>'FROM_LOCATION_CODE', '') THEN
        RETURN jsonb_build_object('error',
            'From Location (' || COALESCE(p->>'FROM_LOCATION_CODE', 'blank') ||
            ') no longer matches the asset''s current location (' ||
            COALESCE(btrim(v_reg_location), 'blank') ||
            '). Re-select the asset code to reload current location details.');
    END IF;

    -- Department and employee are nullable — treat NULL as empty for comparison
    IF COALESCE(btrim(v_reg_department), '') <> COALESCE(p->>'FROM_DEPARTMENT_CODE', '') THEN
        RETURN jsonb_build_object('error',
            'From Department (' || COALESCE(p->>'FROM_DEPARTMENT_CODE', 'blank') ||
            ') no longer matches the asset''s current department (' ||
            COALESCE(btrim(v_reg_department), 'blank') ||
            '). Re-select the asset code to reload current location details.');
    END IF;

    IF COALESCE(btrim(v_reg_employee), '') <> COALESCE(p->>'FROM_EMPLOYEE_CODE', '') THEN
        RETURN jsonb_build_object('error',
            'From Employee (' || COALESCE(p->>'FROM_EMPLOYEE_CODE', 'blank') ||
            ') no longer matches the asset''s current custodian (' ||
            COALESCE(btrim(v_reg_employee), 'blank') ||
            '). Re-select the asset code to reload current location details.');
    END IF;

    RETURN NULL;
END;
$$;
