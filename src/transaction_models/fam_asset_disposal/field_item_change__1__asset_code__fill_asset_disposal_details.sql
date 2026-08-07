/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_disposal
event_type: field_item_change
function_name: fill_asset_disposal_details
form_no: 1
field_name: asset_code
language: plpgsql
description: Fill asset name, capitalization date and computed NBV from the asset's depreciation records
functional_specification: On change of ASSET_CODE, select ASSET_NAME and CAPITALIZATION_DATE from FAM_ASSET_REGISTER for the given ASSET_CODE. Also compute NET_BOOK_VALUE_AS_ON_DISPOSAL as the asset's total capitalized cost less accumulated Companies Act depreciation posted up to the disposal date (from the Companies Act depreciation generation/posting records). Return {"updates": {...}} setting asset_name, capitalization_date and net_book_value_as_on_disposal, and also recompute profit_loss_on_disposal = sale_value - net_book_value_as_on_disposal. NOTE: no accumulated-depreciation/WDV ledger table exists yet in this project's design; until the Depreciation (Companies Act) generation object is built and exposes a queryable WDV/accumulated-depreciation source, net_book_value_as_on_disposal should default to the asset's TOTAL_CAPITALIZED_COST (once that column is added to FAM_ASSET_REGISTER) or 0, and this function must be revisited once that source exists.
business_logic: Fill asset name, capitalization date and computed NBV from the asset's depreciation records
*/

CREATE OR REPLACE FUNCTION fill_asset_disposal_details(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
/*
  NBV NOTE
  --------
  No accumulated-depreciation or WDV ledger table exists in this project yet.
  NET_BOOK_VALUE_AS_ON_DISPOSAL is therefore defaulted to 0 until the Companies
  Act depreciation generation object is built and exposes a queryable balance.
  Once that source is available:
    1. Replace v_nbv := 0 with a query against the depreciation ledger.
    2. TOTAL_CAPITALIZED_COST on FAM_ASSET_REGISTER (pending addition) should
       serve as the upper bound for sanity checking.
*/
DECLARE
    v_asset_code         TEXT;
    v_asset_name         TEXT;
    v_cap_date           DATE;
    v_sale_value         NUMERIC(14,2);
    v_nbv                NUMERIC(14,2) := 0;   -- placeholder until ledger exists
    v_profit_loss        NUMERIC(14,2);
BEGIN
    v_asset_code := p->>'ASSET_CODE';

    -- Clear dependent fields when asset code is removed.
    IF v_asset_code IS NULL OR v_asset_code = '' THEN
        RETURN jsonb_build_object('updates', jsonb_build_object(
            'ASSET_NAME',                   NULL,
            'CAPITALIZATION_DATE',          NULL,
            'NET_BOOK_VALUE_AS_ON_DISPOSAL', NULL,
            'PROFIT_LOSS_ON_DISPOSAL',      NULL
        ));
    END IF;

    -- Fetch master data from Asset Register.
    SELECT ASSET_NAME, CAPITALIZATION_DATE
      INTO v_asset_name, v_cap_date
      FROM FAM_ASSET_REGISTER
     WHERE ASSET_CODE = v_asset_code;

    IF NOT FOUND THEN
        -- Asset code not in register; clear dependent fields and surface an inline error.
        RETURN jsonb_build_object(
            'error', 'Asset ' || v_asset_code || ' not found in the Asset Register.',
            'updates', jsonb_build_object(
                'ASSET_NAME',                   NULL,
                'CAPITALIZATION_DATE',          NULL,
                'NET_BOOK_VALUE_AS_ON_DISPOSAL', NULL,
                'PROFIT_LOSS_ON_DISPOSAL',      NULL
            )
        );
    END IF;

    -- Read current SALE_VALUE from payload (may be NULL for Scrap disposals).
    v_sale_value := (p->>'SALE_VALUE')::NUMERIC(14,2);

    -- NBV stub: 0 until Companies Act depreciation ledger is available.
    -- v_nbv := <query accumulated depreciation up to DISPOSAL_DATE>;

    -- PROFIT / LOSS = Sale Value − Net Book Value (loss when negative).
    v_profit_loss := COALESCE(v_sale_value, 0) - v_nbv;

    RETURN jsonb_build_object('updates', jsonb_build_object(
        'ASSET_NAME',                    v_asset_name,
        'CAPITALIZATION_DATE',           v_cap_date,
        'NET_BOOK_VALUE_AS_ON_DISPOSAL', v_nbv,
        'PROFIT_LOSS_ON_DISPOSAL',       v_profit_loss
    ));
END;
$$;
