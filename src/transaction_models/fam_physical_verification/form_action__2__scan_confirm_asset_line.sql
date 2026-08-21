/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: scan_confirm_asset_line
form_no: 2
action_name: Scan to Confirm
language: plpgsql
description: Confirm an asset by scanning its QR/barcode
functional_specification: Resolve the asset to confirm either from the QR tag image picked in SCAN_QR_IMAGE_URL or from the ASSET_CODE keyed in on the line. Validate the resolved code exists in FAM_ASSET_REGISTER and belongs to this verification cycle, then stamp VERIFIED_DATE with today's date and set PHYSICAL_STATUS_FOUND = 'FOUND' (lines already marked Damaged or Extra-Unregistered keep their status and are only date-stamped). Return {"updates": {...}} carrying the resolved asset code, its name, expected location/employee, the verified date, the status and a cleared SCAN_QR_IMAGE_URL.
business_logic: Confirm an asset by scanning its QR/barcode
*/

CREATE OR REPLACE FUNCTION scan_confirm_asset_line(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no       text;
    v_row_asset      text;
    v_current_status text;
    v_scan_url       text;
    v_decoded        text;
    v_asset_code     text;
    v_asset          record;
    v_in_cycle       boolean;
    v_new_status     text;
    v_updates        jsonb := '{}'::jsonb;
BEGIN
    v_cycle_no       := COALESCE(p->>'VERIFICATION_CYCLE_NO', p->>'verification_cycle_no');
    v_row_asset      := NULLIF(BTRIM(COALESCE(p->>'ASSET_CODE', p->>'asset_code', '')), '');
    v_current_status := UPPER(COALESCE(p->>'PHYSICAL_STATUS_FOUND', p->>'physical_status_found', ''));
    v_scan_url       := NULLIF(BTRIM(COALESCE(p->>'SCAN_QR_IMAGE_URL', p->>'scan_qr_image_url', '')), '');

    IF v_scan_url IS NULL AND v_row_asset IS NULL THEN
        RETURN jsonb_build_object('error', 'Pick the asset''s QR tag image or enter an asset code first.');
    END IF;

    IF v_scan_url IS NOT NULL THEN
        -- Decode the payload carried by the picked/captured QR tag image, then normalise it the
        -- same way fam_verification_execution.scan_asset_into_verification does: an
        -- 'ASSET_CODE=<code>' style payload keeps only the code, a URL keeps only its last
        -- segment, and the result is trimmed and upper-cased.
        IF POSITION('ASSET_CODE=' IN UPPER(v_scan_url)) > 0 THEN
            v_decoded := SUBSTRING(v_scan_url FROM POSITION('ASSET_CODE=' IN UPPER(v_scan_url)) + 11);
            v_decoded := split_part(split_part(v_decoded, '&', 1), '#', 1);
        ELSE
            v_decoded := split_part(split_part(v_scan_url, '#', 1), '?', 1);
            v_decoded := regexp_replace(v_decoded, '^.*/', '');
            -- A bare image file name carries no readable payload
            IF v_decoded ~* '\.(jpg|jpeg|png|gif|bmp|webp|heic|heif|tif|tiff)$' THEN
                v_decoded := NULL;
            END IF;
        END IF;

        v_asset_code := NULLIF(UPPER(BTRIM(COALESCE(v_decoded, ''))), '');

        IF v_asset_code IS NULL THEN
            RETURN jsonb_build_object('error', 'No QR code could be read from the selected image. Try a clearer photo or enter the asset code manually.');
        END IF;
    ELSE
        v_asset_code := v_row_asset;
    END IF;

    SELECT r.ASSET_CODE, r.ASSET_NAME, r.LOCATION_CODE, r.ASSIGNED_EMPLOYEE_CODE
      INTO v_asset
      FROM FAM_ASSET_REGISTER r
     WHERE r.ASSET_CODE = v_asset_code;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Asset ' || v_asset_code || ' does not exist in the Asset Register.');
    END IF;

    -- The planned list is fixed: the asset must already be a line of this cycle, or be the
    -- asset the row currently being edited stands for.
    v_in_cycle := (v_row_asset IS NOT NULL AND v_row_asset = v_asset_code);

    IF NOT v_in_cycle THEN
        SELECT EXISTS (
            SELECT 1
              FROM FAM_PHYSICAL_VERIFICATION_LINE l
             WHERE l.VERIFICATION_CYCLE_NO = v_cycle_no
               AND l.ASSET_CODE = v_asset_code
        ) INTO v_in_cycle;
    END IF;

    IF NOT v_in_cycle THEN
        RETURN jsonb_build_object(
            'error', 'Asset ' || v_asset_code || ' is not part of verification cycle ' || COALESCE(v_cycle_no, '') || '.'
        );
    END IF;

    -- Lines already marked Damaged or Extra-Unregistered keep their status; they are only date-stamped
    IF v_current_status IN ('DAMAGED', 'EXTRA_UNREGISTERED') THEN
        v_new_status := v_current_status;
    ELSE
        v_new_status := 'FOUND';
    END IF;

    IF v_asset.ASSET_CODE IS DISTINCT FROM v_row_asset THEN
        v_updates := v_updates || jsonb_build_object('asset_code', v_asset.ASSET_CODE);
    END IF;

    IF COALESCE(v_asset.ASSET_NAME, '') IS DISTINCT FROM COALESCE(p->>'ASSET_NAME', p->>'asset_name', '') THEN
        v_updates := v_updates || jsonb_build_object('asset_name', v_asset.ASSET_NAME);
    END IF;

    IF COALESCE(v_asset.LOCATION_CODE, '') IS DISTINCT FROM COALESCE(p->>'EXPECTED_LOCATION_CODE', p->>'expected_location_code', '') THEN
        v_updates := v_updates || jsonb_build_object('expected_location_code', v_asset.LOCATION_CODE);
    END IF;

    IF COALESCE(v_asset.ASSIGNED_EMPLOYEE_CODE, '') IS DISTINCT FROM COALESCE(p->>'EXPECTED_EMPLOYEE_CODE', p->>'expected_employee_code', '') THEN
        v_updates := v_updates || jsonb_build_object('expected_employee_code', v_asset.ASSIGNED_EMPLOYEE_CODE);
    END IF;

    IF COALESCE(p->>'VERIFIED_DATE', p->>'verified_date', '') IS DISTINCT FROM CURRENT_DATE::text THEN
        v_updates := v_updates || jsonb_build_object('verified_date', CURRENT_DATE);
    END IF;

    IF v_new_status IS DISTINCT FROM COALESCE(p->>'PHYSICAL_STATUS_FOUND', p->>'physical_status_found', '') THEN
        v_updates := v_updates || jsonb_build_object('physical_status_found', v_new_status);
    END IF;

    -- Clear the picked image so the next scan starts fresh
    IF v_scan_url IS NOT NULL THEN
        v_updates := v_updates || jsonb_build_object('scan_qr_image_url', '');
    END IF;

    IF v_updates = '{}'::jsonb THEN
        RETURN NULL;
    END IF;

    RETURN jsonb_build_object('updates', v_updates);
END;
$$;
