/*
project: Fixed_Asset
object_type: T
object_name: fam_asset_register
event_type: field_item_change
function_name: recompute_total_accumulated_depreciation
form_no: 1
field_name: purchase_cost, other_capitalized_cost, opening_wdv, companies_act_useful_life_years, companies_act_method, capitalization_date (one shared function bound to all six columns' item_change)
language: plpgsql
description: Recompute total accumulated depreciation (and its supporting total capitalized cost / residual value / opening accumulated depreciation) for Companies Act reporting
functional_specification: Recompute this asset's derived financial figures whenever the user changes any of PURCHASE_COST, OTHER_CAPITALIZED_COST, OPENING_WDV, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_METHOD or CAPITALIZATION_DATE. Steps: (1) total_capitalized_cost = PURCHASE_COST + OTHER_CAPITALIZED_COST; (2) companies_act_residual_value = round(total_capitalized_cost * COMPANIES_ACT_RESIDUAL_VALUE_PCT / 100, 2); (3) depreciable_base = GREATEST(total_capitalized_cost - companies_act_residual_value, 0); (4) opening_accumulated_depreciation is now DERIVED (OPENING_ACCUMULATED_DEPRECIATION is a protected/read-only column with no item_change of its own): when OPENING_WDV is provided, opening_accumulated_depreciation = GREATEST(LEAST(total_capitalized_cost - OPENING_WDV, depreciable_base), 0); when OPENING_WDV is blank/not entered, opening_accumulated_depreciation = 0 (a fresh asset with no prior depreciation history); (5) effective_end = the DISPOSAL_DATE of this asset's FAM_ASSET_DISPOSAL row when one exists with STATUS = 'APPROVED' for this ASSET_CODE, else CURRENT_DATE; years_elapsed = GREATEST((effective_end - CAPITALIZATION_DATE) / 365.25, 0); (6) if CAPITALIZATION_DATE is null, or COMPANIES_ACT_USEFUL_LIFE_YEARS is null/0, or depreciable_base <= 0: system_dep = 0; if COMPANIES_ACT_METHOD = 'SLM': system_dep = depreciable_base * LEAST(years_elapsed, COMPANIES_ACT_USEFUL_LIFE_YEARS) / COMPANIES_ACT_USEFUL_LIFE_YEARS; else (WDV or anything else, treated as WDV): residual_ratio = COMPANIES_ACT_RESIDUAL_VALUE_PCT/100, falling back to 0.05 when missing/zero to avoid a zero/negative log; r = 1 - residual_ratio ** (1/COMPANIES_ACT_USEFUL_LIFE_YEARS); closing = total_capitalized_cost * (1-r) ** LEAST(years_elapsed, COMPANIES_ACT_USEFUL_LIFE_YEARS); system_dep = total_capitalized_cost - closing; (7) total_accumulated_depreciation = GREATEST(opening_accumulated_depreciation, LEAST(opening_accumulated_depreciation + system_dep, depreciable_base)) -- cap the sum at depreciable_base but never let it fall below the derived opening_accumulated_depreciation itself. Return {"updates": {"total_capitalized_cost": <computed>, "companies_act_residual_value": <computed>, "opening_accumulated_depreciation": <computed>, "total_accumulated_depreciation": <computed>}}. OPENING_ACCUMULATED_DEPRECIATION is protected/read-only on the transaction model, so this function's return is the only way it gets written. This exact function is invoked from every one of PURCHASE_COST, OTHER_CAPITALIZED_COST, OPENING_WDV, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_METHOD and CAPITALIZATION_DATE (each column's item_change) so the figures update live while the user edits any of them.
business_logic: Recompute total accumulated depreciation (and its supporting total capitalized cost / residual value / opening accumulated depreciation) for Companies Act reporting
*/

-- SCHEMA DEPENDENCY: FAM_ASSET_REGISTER must have OPENING_WDV, OPENING_ACCUMULATED_DEPRECIATION
-- and TOTAL_ACCUMULATED_DEPRECIATION columns deployed (they are declared on the
-- transaction model but were not yet present in the live preview DB / Database_Design
-- at the time this function was authored) before this function can run successfully.

CREATE OR REPLACE FUNCTION recompute_total_accumulated_depreciation(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    v_purchase_cost          NUMERIC;
    v_other_cost             NUMERIC;
    v_total_capitalized_cost NUMERIC(14,2);
    v_residual_pct           NUMERIC;
    v_residual_value         NUMERIC(14,2);
    v_useful_life            NUMERIC;
    v_method                 TEXT;
    v_cap_date               DATE;
    v_opening_wdv            NUMERIC;
    v_opening_dep            NUMERIC;
    v_asset_code             TEXT;
    v_as_of_date             DATE;
    v_disposal_date          DATE;
    v_depreciable_base       NUMERIC(14,2);
    v_years_elapsed          NUMERIC;
    v_system_dep             NUMERIC(14,2);
    v_residual_ratio         NUMERIC;
    v_r                      NUMERIC;
    v_closing                NUMERIC;
    v_total_accum_dep        NUMERIC(14,2);
BEGIN
    -- (1) Total capitalized cost — recomputed fresh, never trust a stale value.
    v_purchase_cost := COALESCE((p->>'PURCHASE_COST')::NUMERIC, 0);
    v_other_cost    := COALESCE((p->>'OTHER_CAPITALIZED_COST')::NUMERIC, 0);
    v_total_capitalized_cost := v_purchase_cost + v_other_cost;

    -- (2) Residual value from the category-defaulted residual %.
    v_residual_pct   := NULLIF(p->>'COMPANIES_ACT_RESIDUAL_VALUE_PCT', '')::NUMERIC;
    v_residual_value := ROUND(v_total_capitalized_cost * COALESCE(v_residual_pct, 0) / 100, 2);

    v_useful_life := NULLIF(p->>'COMPANIES_ACT_USEFUL_LIFE_YEARS', '')::NUMERIC;
    v_method      := p->>'COMPANIES_ACT_METHOD';
    v_cap_date    := NULLIF(p->>'CAPITALIZATION_DATE', '')::DATE;
    v_opening_wdv := NULLIF(p->>'OPENING_WDV', '')::NUMERIC;
    v_asset_code  := NULLIF(p->>'ASSET_CODE', '');

    -- "As of" end date: the APPROVED disposal date for this asset when one
    -- exists, else today. ASSET_CODE may be blank on a still-unsaved new row.
    v_as_of_date := CURRENT_DATE;
    IF v_asset_code IS NOT NULL THEN
        SELECT disposal_date INTO v_disposal_date
          FROM fam_asset_disposal
         WHERE asset_code = v_asset_code
           AND status = 'APPROVED'
         ORDER BY disposal_date DESC
         LIMIT 1;
        IF FOUND THEN
            v_as_of_date := v_disposal_date;
        END IF;
    END IF;

    -- (3) Depreciable base, floored at 0.
    v_depreciable_base := GREATEST(v_total_capitalized_cost - v_residual_value, 0);

    -- (4) Opening accumulated depreciation is now DERIVED from Opening WDV
    -- (OPENING_ACCUMULATED_DEPRECIATION is protected/read-only, no direct input).
    -- Blank Opening WDV means "not entered" (fresh asset) -> opening dep = 0.
    IF v_opening_wdv IS NOT NULL THEN
        v_opening_dep := GREATEST(LEAST(v_total_capitalized_cost - v_opening_wdv, v_depreciable_base), 0);
    ELSE
        v_opening_dep := 0;
    END IF;

    -- (5)/(6) Guard: still-Draft / incomplete data -> no system depreciation.
    IF v_cap_date IS NULL OR v_useful_life IS NULL OR v_useful_life = 0
       OR v_depreciable_base <= 0 THEN
        v_system_dep := 0;
    ELSE
        -- Fractional years elapsed (DATE - DATE is integer days in Postgres),
        -- floored at 0 (never negative).
        v_years_elapsed := GREATEST((v_as_of_date - v_cap_date) / 365.25, 0);

        IF v_method = 'SLM' THEN
            v_system_dep := v_depreciable_base
                            * LEAST(v_years_elapsed, v_useful_life)
                            / v_useful_life;
        ELSE
            -- WDV (or anything else — treated as WDV).
            v_residual_ratio := COALESCE(v_residual_pct, 0) / 100;
            IF v_residual_ratio <= 0 THEN
                v_residual_ratio := 0.05;  -- fallback: avoid a zero/negative log
            END IF;
            v_r       := 1 - POWER(v_residual_ratio, 1.0 / v_useful_life);
            v_closing := v_total_capitalized_cost
                         * POWER(1 - v_r, LEAST(v_years_elapsed, v_useful_life));
            v_system_dep := v_total_capitalized_cost - v_closing;
        END IF;
    END IF;

    -- (7) Cap the sum at depreciable_base, but never below opening_accumulated_depreciation.
    v_total_accum_dep := GREATEST(
        v_opening_dep,
        LEAST(v_opening_dep + v_system_dep, v_depreciable_base)
    );

    RETURN jsonb_build_object('updates', jsonb_build_object(
        'TOTAL_CAPITALIZED_COST',           v_total_capitalized_cost,
        'COMPANIES_ACT_RESIDUAL_VALUE',     v_residual_value,
        'OPENING_ACCUMULATED_DEPRECIATION', v_opening_dep,
        'TOTAL_ACCUMULATED_DEPRECIATION',   v_total_accum_dep
    ));
END;
$$;
