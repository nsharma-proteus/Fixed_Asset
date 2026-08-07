/*
project: Fixed_Asset
object_type: T
object_name: fam_warranty_details
event_type: field_validation
function_name: validate_asset_capitalized_for_warranty
form_no: 1
field_name: asset_code
language: plpgsql
description: Ensure the asset is Capitalized before allowing warranty details to be recorded
functional_specification: Verify ASSET_CODE exists in FAM_ASSET_REGISTER and is in Capitalized status, returning an error if not (dependency: FAM_ASSET_REGISTER currently only carries ASSET_CODE, ASSET_NAME, CAPITALIZATION_DATE -- it does not yet have a STATUS column, so until that column is added only existence can be checked here; revisit once STATUS exists).
business_logic: Ensure the asset is Capitalized before allowing warranty details to be recorded
*/

CREATE OR REPLACE FUNCTION validate_asset_capitalized_for_warranty(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_code        text;
    v_cap_date          date;
BEGIN
    v_asset_code := p->>'ASSET_CODE';

    -- Nothing to check if the field is blank
    IF v_asset_code IS NULL OR v_asset_code = '' THEN
        RETURN NULL;
    END IF;

    -- Verify the asset exists and fetch CAPITALIZATION_DATE.
    -- FAM_ASSET_REGISTER has no STATUS column yet; a non-NULL CAPITALIZATION_DATE
    -- is the available proxy for "asset has been capitalized".
    -- Revisit this check once a STATUS column is added to FAM_ASSET_REGISTER.
    SELECT CAPITALIZATION_DATE
      INTO v_cap_date
      FROM FAM_ASSET_REGISTER
     WHERE ASSET_CODE = v_asset_code;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'error',
            'Asset ' || v_asset_code || ' does not exist in the Asset Register.'
        );
    END IF;

    -- Proxy capitalization check: asset is considered capitalized only when
    -- CAPITALIZATION_DATE has been recorded.
    IF v_cap_date IS NULL THEN
        RETURN jsonb_build_object(
            'error',
            'Asset ' || v_asset_code || ' has not yet been capitalized. '
            || 'Warranty details can only be recorded against a capitalized asset.'
        );
    END IF;

    RETURN NULL;  -- asset exists and is capitalized — all good
END;
$$;
