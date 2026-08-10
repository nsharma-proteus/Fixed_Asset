/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_disposal
event_type: action
function_name: approve_asset_disposal
action_name: Approve
language: plpgsql
description: Approve the disposal, mark the asset Disposed and exclude it from future depreciation
functional_specification: Set STATUS to APPROVED on this disposal record (guarded so only a Pending Approval record still in that status is approved). Then UPDATE the Asset Register row for ASSET_CODE, setting its STATUS to DISPOSED and its DISPOSAL_DATE to this disposal's DISPOSAL_DATE, so the asset is excluded from future Companies Act and Income Tax depreciation generation runs and removed from its Income Tax block of assets from the next generation run. Return a confirmation message.
business_logic: Approve the disposal, mark the asset Disposed and exclude it from future depreciation
*/

CREATE OR REPLACE FUNCTION approve_asset_disposal(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_disposal_no   TEXT;
    v_asset_code    TEXT;
    v_status        TEXT;
    v_disposal_date DATE;
    v_rows          INTEGER;
BEGIN
    v_disposal_no   := p->>'DISPOSAL_NO';
    v_asset_code    := p->>'ASSET_CODE';
    v_status        := p->>'STATUS';
    v_disposal_date := (p->>'DISPOSAL_DATE')::DATE;

    -- Only Pending Approval disposals may be approved.
    IF v_status <> 'PENDING_APPROVAL' THEN
        RETURN jsonb_build_object('error',
            'Only disposals in Pending Approval status can be approved. '
            || 'Current status is ''' || COALESCE(v_status, 'Unknown') || '''.');
    END IF;

    -- Mark the disposal as Approved; optimistic-lock guards against concurrent state change.
    UPDATE FAM_ASSET_DISPOSAL
       SET STATUS   = 'APPROVED',
           CHG_DATE = NOW()
     WHERE DISPOSAL_NO = v_disposal_no
       AND STATUS = 'PENDING_APPROVAL';

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RETURN jsonb_build_object('error',
            'Disposal could not be approved — it may have been modified by another user. '
            || 'Please refresh and try again.');
    END IF;

    -- Mark the asset Disposed and record its disposal date; this excludes it from
    -- future Companies Act and Income Tax depreciation generation runs, and removes
    -- it from its IT block of assets from the next generation run onwards.
    UPDATE FAM_ASSET_REGISTER
       SET STATUS        = 'DISPOSED',
           DISPOSAL_DATE  = v_disposal_date
     WHERE ASSET_CODE = v_asset_code;

    RETURN jsonb_build_object('message',
        'Disposal ' || v_disposal_no || ' has been approved. '
        || 'Asset ' || v_asset_code || ' has been marked Disposed as of '
        || COALESCE(v_disposal_date::TEXT, 'the disposal date') || '.');
END;
$$;
