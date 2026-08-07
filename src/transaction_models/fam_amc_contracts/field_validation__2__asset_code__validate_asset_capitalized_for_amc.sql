/*
project: Fixed_Asset
object_type: T
object_name: fam_amc_contracts
event_type: field_validation
function_name: validate_asset_capitalized_for_amc
form_no: 2
field_name: asset_code
language: plpgsql
description: Ensure the asset is Capitalized before allowing it to be added to an AMC contract line
functional_specification: Verify ASSET_CODE exists in FAM_ASSET_REGISTER and is in Capitalized status, returning an error if not (dependency: FAM_ASSET_REGISTER currently only carries ASSET_CODE, ASSET_NAME, CAPITALIZATION_DATE -- it does not yet have a STATUS column, so until that column is added only existence can be checked here; revisit once STATUS exists).
business_logic: Ensure the asset is Capitalized before allowing it to be added to an AMC contract line
*/

CREATE OR REPLACE FUNCTION validate_asset_capitalized_for_amc(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_code text;
BEGIN
    v_asset_code := p->>'ASSET_CODE';

    -- Reject blank/null asset codes early
    IF v_asset_code IS NULL OR v_asset_code = '' THEN
        RETURN jsonb_build_object('error', 'Asset Code is required.');
    END IF;

    -- Verify the asset exists in the Asset Register.
    -- NOTE: FAM_ASSET_REGISTER does not yet carry a STATUS column, so only existence
    -- can be confirmed here.  Once a capitalization-status column is added, extend
    -- this check to also require STATUS = 'CAPITALIZED' (or equivalent).
    IF NOT EXISTS (
        SELECT 1
        FROM fam_asset_register
        WHERE asset_code = v_asset_code
    ) THEN
        RETURN jsonb_build_object(
            'error',
            'Asset ' || v_asset_code || ' does not exist in the Asset Register. '
            || 'Only capitalized assets may be covered under an AMC contract.'
        );
    END IF;

    RETURN NULL;
END;
$$;
