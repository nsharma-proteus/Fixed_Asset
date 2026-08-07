/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: field_item_change
function_name: fill_expected_asset_details
form_no: 2
field_name: asset_code
language: plpgsql
description: Default the expected location/custodian for the scanned asset
functional_specification: On change of ASSET_CODE, default EXPECTED_LOCATION_CODE and EXPECTED_EMPLOYEE_CODE from the asset's current BRANCH_CODE/LOCATION_CODE/ASSIGNED_EMPLOYEE_CODE once those columns exist on FAM_ASSET_REGISTER (dependency: they do not exist yet — only ASSET_CODE, ASSET_NAME, CAPITALIZATION_DATE are currently present, so until this dependency is resolved, default EXPECTED_LOCATION_CODE to the header form's LOCATION_CODE as an interim fallback and leave EXPECTED_EMPLOYEE_CODE blank). Return {"updates": {"expected_location_code": ..., "expected_location_name": ..., "expected_employee_code": ..., "expected_employee_name": ...}}.
business_logic: Default the expected location/custodian for the scanned asset
*/

CREATE OR REPLACE FUNCTION fill_expected_asset_details(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_code    text;
    v_location_code text;
    v_location_name text;
BEGIN
    v_asset_code := p->>'ASSET_CODE';

    -- Clear all dependent fields when asset code is blanked
    IF v_asset_code IS NULL OR v_asset_code = '' THEN
        RETURN jsonb_build_object(
            'updates', jsonb_build_object(
                'expected_location_code', NULL,
                'expected_location_name', NULL,
                'expected_employee_code', NULL,
                'expected_employee_name', NULL
            )
        );
    END IF;

    -- NOTE: FAM_ASSET_REGISTER does not yet have BRANCH_CODE/LOCATION_CODE/ASSIGNED_EMPLOYEE_CODE.
    -- Interim fallback: pull the verification cycle's header location from the saved header row
    -- using VERIFICATION_CYCLE_NO (present in the line payload as the FK).
    -- Revisit once FAM_ASSET_REGISTER exposes the asset's current custodian/location.
    SELECT h.LOCATION_CODE, h.location_name
    INTO   v_location_code, v_location_name
    FROM   FAM_PHYSICAL_VERIFICATION h
    WHERE  h.VERIFICATION_CYCLE_NO = p->>'VERIFICATION_CYCLE_NO';

    RETURN jsonb_build_object(
        'updates', jsonb_build_object(
            'expected_location_code', v_location_code,
            'expected_location_name', v_location_name,
            'expected_employee_code', NULL,   -- to be sourced from FAM_ASSET_REGISTER once available
            'expected_employee_name', NULL
        )
    );
END;
$$;
