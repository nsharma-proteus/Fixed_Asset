/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: action
function_name: load_capitalized_assets_for_verification
action_name: Load Assets
language: plpgsql
description: Load capitalized assets for the selected branch/location into a pick grid
functional_specification: Query FAM_ASSET_REGISTER for assets that are Capitalized and currently located at the header's BRANCH_CODE/LOCATION_CODE (dependency: FAM_ASSET_REGISTER does not yet carry STATUS/BRANCH_CODE/LOCATION_CODE columns needed to filter this way -- revisit once those columns exist, e.g. via the Asset Register object; until then, offer all assets and let the user deselect), excluding ASSET_CODE values already present as lines on this VERIFICATION_CYCLE_NO. Return each candidate as a row with ASSET_CODE, ASSET_NAME, EXPECTED_LOCATION_CODE, EXPECTED_EMPLOYEE_CODE for the user to multi-select in the grid; selected rows are appended as new verification lines.
business_logic: Load capitalized assets for the selected branch/location into a pick grid
*/

CREATE OR REPLACE FUNCTION load_capitalized_assets_for_verification(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no text;
    v_rows     jsonb;
    v_count    integer;
BEGIN
    v_cycle_no := p->>'VERIFICATION_CYCLE_NO';

    -- NOTE: FAM_ASSET_REGISTER has no STATUS/BRANCH_CODE/LOCATION_CODE columns yet.
    -- Future: filter WHERE STATUS = 'CAPITALIZED' AND BRANCH_CODE = header BRANCH_CODE
    --         AND LOCATION_CODE = header LOCATION_CODE once those columns are added.
    -- Interim: use CAPITALIZATION_DATE IS NOT NULL as proxy for a capitalized asset
    -- and present all such assets not already on this cycle for user deselection.
    SELECT COALESCE(
               jsonb_agg(
                   jsonb_build_object(
                       'ASSET_CODE',             ar.ASSET_CODE,
                       'ASSET_NAME',             ar.ASSET_NAME,
                       'EXPECTED_LOCATION_CODE', NULL::text,
                       'EXPECTED_EMPLOYEE_CODE', NULL::text
                   )
                   ORDER BY ar.ASSET_CODE
               ),
               '[]'::jsonb
           )
    INTO v_rows
    FROM FAM_ASSET_REGISTER ar
    WHERE ar.CAPITALIZATION_DATE IS NOT NULL
    AND NOT EXISTS (
        SELECT 1
        FROM FAM_PHYSICAL_VERIFICATION_LINE vl
        WHERE vl.VERIFICATION_CYCLE_NO = v_cycle_no
        AND   vl.ASSET_CODE = ar.ASSET_CODE
    );

    v_count := jsonb_array_length(v_rows);

    RETURN jsonb_build_object(
        'data',    v_rows,
        'message', v_count || ' asset(s) available for selection'
    );
END;
$$;
