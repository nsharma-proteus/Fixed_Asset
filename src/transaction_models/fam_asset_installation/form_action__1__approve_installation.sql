/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_installation
event_type: form_action
function_name: approve_installation
form_no: 1
action_name: Approve
language: plpgsql
description: Approve the installation record and set the asset's put-to-use date
functional_specification: Validate that the record's STATUS is PENDING (already enforced by the pre-action validation). Then: (1) UPDATE FAM_ASSET_INSTALLATION SET STATUS = 'CONFIRMED', CHG_DATE = current timestamp, CHG_USER = current user, CHG_TERM = current terminal WHERE ID = the payload's id. (2) UPDATE FAM_ASSET_REGISTER SET PUT_TO_USE_DATE = the payload's INSTALLATION_DATE WHERE ASSET_CODE = the payload's ASSET_CODE — this PUT_TO_USE_DATE is subsequently used as the depreciation start date for the asset whenever it is later than the asset's CAPITALIZATION_DATE. Return a confirmation message including the asset code and the installation date that was set as the put-to-use date.
business_logic: Approve the installation record and set the asset's put-to-use date
*/

CREATE OR REPLACE FUNCTION approve_installation(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    -- STATUS=PENDING guard is already enforced by the pre-action validation.

    -- (1) Confirm the installation record
    UPDATE fam_asset_installation
    SET    status   = 'CONFIRMED',
           chg_date = CURRENT_TIMESTAMP,
           chg_user = p->>'CHG_USER',
           chg_term = p->>'CHG_TERM'
    WHERE  id = (p->>'ID')::numeric;

    -- (2) Stamp the asset's put-to-use date; used as depreciation start
    --     whenever it falls after the asset's CAPITALIZATION_DATE.
    --     NOTE: PUT_TO_USE_DATE must exist on FAM_ASSET_REGISTER in the schema.
    UPDATE fam_asset_register
    SET    put_to_use_date = (p->>'INSTALLATION_DATE')::date
    WHERE  asset_code = p->>'ASSET_CODE';

    RETURN jsonb_build_object(
        'message',
        'Asset ' || COALESCE(p->>'ASSET_CODE', '') ||
        ' installation approved. Put-to-use date set to ' ||
        COALESCE(p->>'INSTALLATION_DATE', '') || '.'
    );
END;
$$;
