/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_transfer
event_type: field_item_change
function_name: fill_asset_current_location
form_no: 1
field_name: asset_code
language: plpgsql
description: Fill FROM location/custody fields from the asset's current location
functional_specification: On change of ASSET_CODE, look up the asset's current BRANCH_CODE, LOCATION_CODE, DEPARTMENT_CODE and ASSIGNED_EMPLOYEE_CODE (and current STATUS) together with ASSET_NAME. Return {"updates": {...}} setting asset_name, from_branch_code, from_location_code, from_department_code and from_employee_code to those current values (also resolve and fill from_branch_name/from_location_name/from_department_name/from_employee_name from the respective master tables). If the asset's current status is not Capitalized/Active, return an error instead. NOTE: FAM_ASSET_REGISTER is currently designed with only ASSET_CODE, ASSET_NAME and CAPITALIZATION_DATE; BRANCH_CODE/LOCATION_CODE/DEPARTMENT_CODE/ASSIGNED_EMPLOYEE_CODE/STATUS must be added to it (by the Asset Register object) before this function can be fully implemented.
business_logic: Fill FROM location/custody fields from the asset's current location
*/

-- SCHEMA DEPENDENCY: FAM_ASSET_REGISTER must have BRANCH_CODE, LOCATION_CODE,
-- DEPARTMENT_CODE, ASSIGNED_EMPLOYEE_CODE, and STATUS columns added by the
-- Asset Register object before this function can be deployed.

CREATE OR REPLACE FUNCTION fill_asset_current_location(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_name      text;
    v_asset_status    text;
    v_branch_code     text;
    v_location_code   text;
    v_department_code text;
    v_employee_code   text;
    v_branch_name     text;
    v_location_name   text;
    v_department_name text;
    v_employee_name   text;
BEGIN
    -- Fetch asset details and its current location/custody in one query,
    -- resolving display names from master tables via LEFT JOINs.
    -- All JOINs use column-to-column predicates — fully index-friendly.
    SELECT ar.asset_name,
           ar.status,
           ar.branch_code,
           ar.location_code,
           ar.department_code,
           ar.assigned_employee_code,
           bm.branch_name,
           lm.location_name,
           dm.department_name,
           em.employee_name
    INTO   v_asset_name, v_asset_status,
           v_branch_code, v_location_code, v_department_code, v_employee_code,
           v_branch_name, v_location_name, v_department_name, v_employee_name
    FROM   fam_asset_register ar
    LEFT JOIN fam_branch_master     bm ON bm.branch_code      = ar.branch_code
    LEFT JOIN fam_location_master   lm ON lm.branch_code      = ar.branch_code
                                      AND lm.location_code    = ar.location_code
    LEFT JOIN fam_department_master dm ON dm.branch_code      = ar.branch_code
                                      AND dm.department_code  = ar.department_code
    LEFT JOIN fam_employee_master   em ON em.employee_code    = ar.assigned_employee_code
    WHERE  ar.asset_code = p->>'ASSET_CODE';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error',
            'Asset ' || COALESCE(p->>'ASSET_CODE', '') ||
            ' was not found in the Asset Register.');
    END IF;

    -- Block non-transferable assets before populating any fields
    IF v_asset_status NOT IN ('CAPITALIZED', 'ACTIVE') THEN
        RETURN jsonb_build_object('error',
            'Asset ' || COALESCE(p->>'ASSET_CODE', '') ||
            ' cannot be transferred. Its current status is ''' ||
            COALESCE(v_asset_status, 'Unknown') ||
            ''' — only Capitalized or Active assets are eligible for transfer.');
    END IF;

    -- Populate asset name and all FROM location/custody fields
    RETURN jsonb_build_object('updates', jsonb_build_object(
        'ASSET_NAME',           v_asset_name,
        'FROM_BRANCH_CODE',     v_branch_code,
        'FROM_BRANCH_NAME',     v_branch_name,
        'FROM_LOCATION_CODE',   v_location_code,
        'FROM_LOCATION_NAME',   v_location_name,
        'FROM_DEPARTMENT_CODE', v_department_code,
        'FROM_DEPARTMENT_NAME', v_department_name,
        'FROM_EMPLOYEE_CODE',   v_employee_code,
        'FROM_EMPLOYEE_NAME',   v_employee_name
    ));
END;
$$;
