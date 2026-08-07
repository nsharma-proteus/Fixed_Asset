/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: field_validation
function_name: validate_asset_code_for_verification
form_no: 2
field_name: asset_code
language: plpgsql
description: Validate the asset code against the register unless the line is Extra-Unregistered
functional_specification: If PHYSICAL_STATUS_FOUND is not 'EXTRA_UNREGISTERED', verify ASSET_CODE exists in FAM_ASSET_REGISTER and is Capitalized, returning an error if not (dependency: FAM_ASSET_REGISTER does not yet carry a STATUS column, so until it is added only existence can be checked here — revisit once STATUS exists). If PHYSICAL_STATUS_FOUND = 'EXTRA_UNREGISTERED', skip the existence/status check entirely since this line records an asset physically found that is not (yet) in the register.
business_logic: Validate the asset code against the register unless the line is Extra-Unregistered
*/

CREATE OR REPLACE FUNCTION validate_asset_code_for_verification(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_code text;
    v_dummy      text;
BEGIN
    -- Extra-Unregistered lines represent assets found but not in the register; skip check
    IF p->>'PHYSICAL_STATUS_FOUND' = 'EXTRA_UNREGISTERED' THEN
        RETURN NULL;
    END IF;

    v_asset_code := p->>'ASSET_CODE';

    IF v_asset_code IS NULL OR v_asset_code = '' THEN
        RETURN NULL;  -- required-field enforcement handled by the platform
    END IF;

    SELECT ASSET_CODE INTO v_dummy
    FROM FAM_ASSET_REGISTER
    WHERE ASSET_CODE = v_asset_code;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'error', 'Asset Code ' || v_asset_code || ' does not exist in the Asset Register.'
        );
    END IF;

    -- NOTE: FAM_ASSET_REGISTER has no STATUS column yet.
    -- Capitalization status check (e.g. STATUS = 'CAPITALIZED') must be added here
    -- once that column is available on FAM_ASSET_REGISTER.

    RETURN NULL;
END;
$$;
