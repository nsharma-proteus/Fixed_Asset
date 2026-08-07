/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_disposal
event_type: field_validation
function_name: check_asset_not_disposed
form_no: 1
field_name: asset_code
language: plpgsql
description: Validate the asset is not already Disposed before allowing a new disposal
functional_specification: Look up the asset's current STATUS on the Asset Register for ASSET_CODE; return an error (e.g. {"error":"..."}) if it is already Disposed. NOTE: FAM_ASSET_REGISTER is currently designed with only ASSET_CODE, ASSET_NAME and CAPITALIZATION_DATE columns; a STATUS column must be added to it (by the Asset Register object) before this check can be implemented.
business_logic: Validate the asset is not already Disposed before allowing a new disposal
*/

CREATE OR REPLACE FUNCTION check_asset_not_disposed(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
/*
  IMPLEMENTATION NOTE
  -------------------
  FAM_ASSET_REGISTER currently has only three columns: ASSET_CODE, ASSET_NAME,
  and CAPITALIZATION_DATE.  The STATUS column required to detect a disposed asset
  does not yet exist on that table.

  Once the Asset Register object adds STATUS (e.g. 'ACTIVE' / 'DISPOSED'), remove
  the stub RETURN NULL and activate the commented-out block below.

  When that column exists the logic must also check for an open (non-cancelled)
  FAM_ASSET_DISPOSAL row for the same ASSET_CODE so that a second disposal cannot
  be started while one is in progress.
*/
DECLARE
    v_asset_code TEXT;
    -- v_status TEXT;   -- uncomment once FAM_ASSET_REGISTER.STATUS exists
BEGIN
    v_asset_code := p->>'ASSET_CODE';

    IF v_asset_code IS NULL OR v_asset_code = '' THEN
        RETURN NULL;
    END IF;

    -- -----------------------------------------------------------------------
    -- ACTIVATE once FAM_ASSET_REGISTER.STATUS column is available:
    --
    -- SELECT STATUS
    --   INTO v_status
    --   FROM FAM_ASSET_REGISTER
    --  WHERE ASSET_CODE = v_asset_code;
    --
    -- IF NOT FOUND THEN
    --     RETURN jsonb_build_object('error',
    --         'Asset ' || v_asset_code || ' does not exist in the Asset Register.');
    -- END IF;
    --
    -- IF v_status = 'DISPOSED' THEN
    --     RETURN jsonb_build_object('error',
    --         'Asset ' || v_asset_code || ' has already been disposed and cannot be disposed again.');
    -- END IF;
    -- -----------------------------------------------------------------------

    -- Stub: FAM_ASSET_REGISTER.STATUS not yet present — no check performed.
    RETURN NULL;
END;
$$;
