/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_disposal
event_type: action
function_name: approve_asset_disposal
action_name: Approve
language: plpgsql
description: Approve the disposal, mark the asset Disposed and exclude it from future depreciation
functional_specification: Set STATUS to APPROVED on this disposal record. Then UPDATE the Asset Register row for ASSET_CODE, setting its STATUS to DISPOSED so the asset is excluded from future Companies Act and Income Tax depreciation generation runs and removed from its Income Tax block of assets from the next generation run. Return a confirmation message. Depends on FAM_ASSET_REGISTER carrying a STATUS column (currently only ASSET_CODE, ASSET_NAME and CAPITALIZATION_DATE exist there).
business_logic: Approve the disposal, mark the asset Disposed and exclude it from future depreciation
*/

CREATE OR REPLACE FUNCTION approve_asset_disposal(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
/*
  ASSET REGISTER STATUS NOTE
  --------------------------
  FAM_ASSET_REGISTER currently carries only ASSET_CODE, ASSET_NAME, and
  CAPITALIZATION_DATE.  The UPDATE that marks the asset as DISPOSED (required to
  exclude it from future depreciation runs) is guarded by a comment below and must
  be activated once the Asset Register object adds a STATUS column.
*/
DECLARE
    v_disposal_no TEXT;
    v_asset_code  TEXT;
    v_status      TEXT;
BEGIN
    v_disposal_no := p->>'DISPOSAL_NO';
    v_asset_code  := p->>'ASSET_CODE';
    v_status      := p->>'STATUS';

    -- Only Pending Approval disposals may be approved.
    IF v_status <> 'PENDING_APPROVAL' THEN
        RETURN jsonb_build_object('error',
            'Only disposals in Pending Approval status can be approved. '
            || 'Current status is ''' || COALESCE(v_status, 'Unknown') || '''.');
    END IF;

    -- Mark the disposal as Approved.
    UPDATE FAM_ASSET_DISPOSAL
       SET STATUS   = 'APPROVED',
           CHG_DATE = NOW()
     WHERE DISPOSAL_NO = v_disposal_no;

    -- -----------------------------------------------------------------------
    -- ACTIVATE once FAM_ASSET_REGISTER.STATUS column is present:
    --
    -- UPDATE FAM_ASSET_REGISTER
    --    SET STATUS = 'DISPOSED'
    --  WHERE ASSET_CODE = v_asset_code;
    --
    -- This prevents the asset from appearing in future Companies Act and Income
    -- Tax depreciation generation runs, and removes it from its IT block of
    -- assets from the next generation run onwards.
    -- -----------------------------------------------------------------------

    RETURN jsonb_build_object('message',
        'Disposal ' || v_disposal_no || ' has been approved. '
        || 'Asset ' || v_asset_code || ' will be marked Disposed once '
        || 'FAM_ASSET_REGISTER.STATUS is available.');
END;
$$;
