/*
project: Fixed_Asset
object_type: T
object_name: fam_physical_verification
event_type: form_action
function_name: load_capitalized_assets_for_verification
form_no: 1
action_name: Load Assets
language: plpgsql
description: Load assets matching the branch, location, category and last-verified-age criteria into a pick grid
functional_specification: This action runs on the header (Verification Cycle) form, so its payload is FLAT and carries the header's own columns directly -- BRANCH_CODE, LOCATION_CODE, CATEGORY_CODE, NOT_VERIFIED_SINCE_MONTHS and VERIFICATION_CYCLE_NO -- with no lookup needed. Query FAM_ASSET_REGISTER for assets whose BRANCH_CODE = the payload BRANCH_CODE; treat LOCATION_CODE as an OPTIONAL filter -- when it is blank/null (meaning 'All Locations'), match any location within the branch, otherwise restrict to LOCATION_CODE = the payload LOCATION_CODE. Restrict to CATEGORY_CODE = the payload CATEGORY_CODE when that value is supplied, and restrict to capitalized/active assets (use the real STATUS / CAPITALIZATION_DATE columns as defined in Database_Design/FAM_ASSET_REGISTER.json). Exclude any ASSET_CODE already present as a line for this VERIFICATION_CYCLE_NO in FAM_PHYSICAL_VERIFICATION_LINE. When the payload's NOT_VERIFIED_SINCE_MONTHS is supplied and greater than 0, also exclude any asset whose most recent FAM_PHYSICAL_VERIFICATION_LINE.VERIFIED_DATE (max over all cycles for that ASSET_CODE) is later than today minus that many months; assets that have never been verified are always included. Return each candidate as a row with ASSET_CODE, ASSET_NAME, EXPECTED_LOCATION_CODE, EXPECTED_EMPLOYEE_CODE and the asset last-verified date for the user to multi-select; selected rows are appended as new verification lines on this form.
business_logic: Load assets matching the branch, location, category and last-verified-age criteria into a pick grid
*/

CREATE OR REPLACE FUNCTION load_capitalized_assets_for_verification(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_cycle_no      text    := p->>'VERIFICATION_CYCLE_NO';
    v_branch_code   text    := p->>'BRANCH_CODE';
    v_location_code text    := p->>'LOCATION_CODE';
    v_category_code text    := p->>'CATEGORY_CODE';
    v_since_months  numeric := NULLIF(p->>'NOT_VERIFIED_SINCE_MONTHS', '')::numeric;
    v_cutoff_date   date;
    v_rows          jsonb;
BEGIN
    -- This action runs on the header form, so all its criteria columns arrive
    -- directly at the top level of the payload -- no header lookup needed.

    -- Compute the last-verified cutoff: assets verified AFTER this date are excluded
    -- (they were verified within the requested window and don't need re-verification yet)
    IF v_since_months IS NOT NULL AND v_since_months > 0 THEN
        v_cutoff_date := CURRENT_DATE - (v_since_months || ' months')::interval;
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'ASSET_CODE',             ar.asset_code,
                'ASSET_NAME',             ar.asset_name,
                'EXPECTED_LOCATION_CODE', ar.location_code,
                'EXPECTED_EMPLOYEE_CODE', ar.assigned_employee_code,
                'LAST_VERIFIED_DATE',     lv.last_verified
            )
            ORDER BY ar.asset_code
        ),
        '[]'::jsonb
    )
    INTO v_rows
    FROM fam_asset_register ar
    -- Derive the most-recent verified date for each asset across all cycles
    LEFT JOIN (
        SELECT   pvl.asset_code,
                 MAX(pvl.verified_date) AS last_verified
        FROM     fam_physical_verification_line pvl
        WHERE    pvl.verified_date IS NOT NULL
        GROUP BY pvl.asset_code
    ) lv ON lv.asset_code = ar.asset_code
    WHERE ar.branch_code   = v_branch_code
      -- Optional location filter (blank/null header value means "all locations in the branch")
      AND (v_location_code IS NULL OR v_location_code = '' OR ar.location_code = v_location_code)
      -- Capitalized/active assets only: STATUS carries the lifecycle value and
      -- CAPITALIZATION_DATE must actually be set and reached
      AND ar.status               = 'CAPITALIZED'
      AND ar.capitalization_date IS NOT NULL
      AND ar.capitalization_date <= CURRENT_DATE
      -- Optional category filter (applied only when the header value is present)
      AND (v_category_code IS NULL OR v_category_code = '' OR ar.category_code = v_category_code)
      -- Skip assets already loaded as lines for this cycle
      AND NOT EXISTS (
              SELECT 1
              FROM   fam_physical_verification_line pvl2
              WHERE  pvl2.verification_cycle_no = v_cycle_no
                AND  pvl2.asset_code            = ar.asset_code
          )
      -- Age filter: keep only assets never verified, or last verified strictly
      -- before the cutoff (CURRENT_DATE minus NOT_VERIFIED_SINCE_MONTHS)
      AND (
              v_cutoff_date     IS NULL
           OR lv.last_verified  IS NULL
           OR lv.last_verified  <  v_cutoff_date
          );

    IF v_rows = '[]'::jsonb THEN
        RETURN jsonb_build_object(
            'rows',    v_rows,
            'message', 'No assets match the branch, location, category and not-verified-since criteria.'
        );
    END IF;

    RETURN jsonb_build_object('rows', v_rows);
END;
$$;
