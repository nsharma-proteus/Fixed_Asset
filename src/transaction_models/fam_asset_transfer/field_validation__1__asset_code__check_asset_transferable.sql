/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_transfer
event_type: field_validation
function_name: check_asset_transferable
form_no: 1
field_name: asset_code
language: plpgsql
description: Validate the asset is Capitalized/Active before allowing a transfer
functional_specification: Look up the asset's current STATUS on the Asset Register for ASSET_CODE; return an error (e.g. {"error":"..."}) if it is not Capitalized or Active (Draft, Pending Approval, Under Transfer, Disposed and Under Investigation are not transferable). NOTE: FAM_ASSET_REGISTER is currently designed with only ASSET_CODE, ASSET_NAME and CAPITALIZATION_DATE columns; a STATUS column must be added to it (by the Asset Register object) before this check can be implemented.
business_logic: Validate the asset is Capitalized/Active before allowing a transfer
*/

-- SCHEMA DEPENDENCY: FAM_ASSET_REGISTER must have a STATUS column added by the
-- Asset Register object before this function can be deployed.
-- Expected transferable values: 'CAPITALIZED', 'ACTIVE'
-- Non-transferable: 'DRAFT', 'PENDING_APPROVAL', 'UNDER_TRANSFER', 'DISPOSED', 'UNDER_INVESTIGATION'

CREATE OR REPLACE FUNCTION check_asset_transferable(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_asset_status text;
BEGIN
    -- Look up the asset's current status from the Asset Register
    SELECT status
    INTO   v_asset_status
    FROM   fam_asset_register
    WHERE  asset_code = p->>'ASSET_CODE';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error',
            'Asset ' || COALESCE(p->>'ASSET_CODE', '') ||
            ' was not found in the Asset Register.');
    END IF;

    -- Only Capitalized or Active assets may be transferred
    IF v_asset_status NOT IN ('CAPITALIZED', 'ACTIVE') THEN
        RETURN jsonb_build_object('error',
            'Asset ' || COALESCE(p->>'ASSET_CODE', '') ||
            ' cannot be transferred. Its current status is ''' ||
            COALESCE(v_asset_status, 'Unknown') ||
            ''' — only Capitalized or Active assets are eligible for transfer.');
    END IF;

    RETURN NULL;
END;
$$;
