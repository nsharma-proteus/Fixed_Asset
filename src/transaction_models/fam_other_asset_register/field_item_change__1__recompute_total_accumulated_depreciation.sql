/*
project: Fixed_Asset
object_type: T
object_name: fam_other_asset_register
event_type: field_item_change
function_name: recompute_total_accumulated_depreciation
form_no: 1
field_name: purchase_cost, other_capitalized_cost (shared function bound to both columns' item_change)
language: plpgsql
description: Recompute the total value (Purchase Cost + Other Capitalized Cost) shown on this record
functional_specification: Same shared function as the Asset Register (fam_asset_register). On this screen every row is ASSET_TYPE = 'OTHER_ASSET' and carries no CAPITALIZATION_DATE / COMPANIES_ACT_USEFUL_LIFE_YEARS, so the function's existing guard (missing CAPITALIZATION_DATE / USEFUL_LIFE_YEARS) always applies: it must still compute and return total_capitalized_cost = PURCHASE_COST + OTHER_CAPITALIZED_COST (used here as the 'Total Value' of the item) and must NOT error or block the save when the Companies Act / Income Tax fields it also computes (companies_act_residual_value, opening_accumulated_depreciation, total_accumulated_depreciation) have no corresponding column on this form — those keys are simply ignored by the runtime for this object. Return {"updates": {"total_capitalized_cost": <computed>, ...}} exactly as on fam_asset_register.
business_logic: Recompute the total value (Purchase Cost + Other Capitalized Cost) shown on this record
*/

-- Deliberately simpler than fam_asset_register's implementation of the same
-- method name: an OTHER_ASSET row never carries a CAPITALIZATION_DATE or a
-- COMPANIES_ACT_USEFUL_LIFE_YEARS on THIS form, so the depreciation branch of
-- the shared logic (years-elapsed / SLM / WDV system-depreciation math and
-- the FAM_ASSET_DISPOSAL lookup) always takes its "no depreciation" guard
-- path. Rather than duplicate that dead code path here, this function
-- computes only the total value and returns the other three keys as their
-- guarded ("no depreciation yet") value of 0 — the same value the full
-- fam_asset_register function would return once CAPITALIZATION_DATE /
-- COMPANIES_ACT_USEFUL_LIFE_YEARS are absent. Those three keys have no
-- matching column on the fam_other_asset_register form and are ignored by
-- the runtime for this object; they are included only to keep the return
-- shape identical to the shared method on fam_asset_register.

CREATE OR REPLACE FUNCTION recompute_total_accumulated_depreciation(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_purchase_cost          NUMERIC;
    v_other_cost              NUMERIC;
    v_total_capitalized_cost  NUMERIC(14,2);
BEGIN
    -- Total value — recomputed fresh, never trust a stale value.
    v_purchase_cost := COALESCE((p->>'PURCHASE_COST')::NUMERIC, 0);
    v_other_cost    := COALESCE((p->>'OTHER_CAPITALIZED_COST')::NUMERIC, 0);
    v_total_capitalized_cost := v_purchase_cost + v_other_cost;

    RETURN jsonb_build_object('updates', jsonb_build_object(
        'TOTAL_CAPITALIZED_COST',           v_total_capitalized_cost,
        'COMPANIES_ACT_RESIDUAL_VALUE',     0,
        'OPENING_ACCUMULATED_DEPRECIATION', 0,
        'TOTAL_ACCUMULATED_DEPRECIATION',   0
    ));
END;
$$;
