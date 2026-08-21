# project: Fixed_Asset
# object_type: T
# object_name: fam_asset_register
# event_type: field_item_change
# function_name: recompute_total_accumulated_depreciation
# form_no: 1
# field_name: other_capitalized_cost
# language: python
# description: Recompute total accumulated depreciation (and its supporting total capitalized cost / residual value / opening accumulated depreciation) for Companies Act reporting
# functional_specification: Recompute this asset's derived financial figures whenever the user changes any of PURCHASE_COST, OTHER_CAPITALIZED_COST, OPENING_WDV, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_METHOD or CAPITALIZATION_DATE. Steps: (1) total_capitalized_cost = PURCHASE_COST + OTHER_CAPITALIZED_COST; (2) companies_act_residual_value = round(total_capitalized_cost * COMPANIES_ACT_RESIDUAL_VALUE_PCT / 100, 2); (3) depreciable_base = GREATEST(total_capitalized_cost - companies_act_residual_value, 0); (4) opening_accumulated_depreciation is DERIVED (OPENING_ACCUMULATED_DEPRECIATION is a protected/read-only column with no item_change of its own): when OPENING_WDV is provided, opening_accumulated_depreciation = GREATEST(LEAST(total_capitalized_cost - OPENING_WDV, depreciable_base), 0); when OPENING_WDV is blank/not entered, opening_accumulated_depreciation = 0 (a fresh asset with no prior depreciation history); (5) years_elapsed = fractional years between CAPITALIZATION_DATE and LEAST(CURRENT_DATE, effective_end), floored at 0, where effective_end = the DISPOSAL_DATE of this asset's FAM_ASSET_DISPOSAL row when one exists with STATUS = 'APPROVED' for this ASSET_CODE, else CURRENT_DATE; (6) if COMPANIES_ACT_METHOD = 'SLM': system_dep = depreciable_base * min(years_elapsed, COMPANIES_ACT_USEFUL_LIFE_YEARS) / COMPANIES_ACT_USEFUL_LIFE_YEARS; if COMPANIES_ACT_METHOD = 'WDV': r = 1 - (companies_act_residual_value / total_capitalized_cost) ** (1 / COMPANIES_ACT_USEFUL_LIFE_YEARS) -- guard divide-by-zero / a zero residual value by capping r at a safe maximum (e.g. 0.999) so the asset's implied closing value never goes below companies_act_residual_value; system_dep = total_capitalized_cost - total_capitalized_cost * (1 - r) ** years_elapsed; (7) total_accumulated_depreciation = GREATEST(opening_accumulated_depreciation, LEAST(opening_accumulated_depreciation + system_dep, depreciable_base)) -- i.e. cap the sum at depreciable_base (total_capitalized_cost - companies_act_residual_value) but never let it fall below the derived opening_accumulated_depreciation itself. Guard: if COMPANIES_ACT_USEFUL_LIFE_YEARS is missing/zero or CAPITALIZATION_DATE is missing (asset still Draft), return total_accumulated_depreciation = opening_accumulated_depreciation while still returning total_capitalized_cost, companies_act_residual_value and opening_accumulated_depreciation computed normally. Return {"updates": {"total_capitalized_cost": <computed>, "companies_act_residual_value": <computed>, "opening_accumulated_depreciation": <computed>, "total_accumulated_depreciation": <computed>}}. OPENING_ACCUMULATED_DEPRECIATION is protected/read-only on the transaction model, so this function's return is the only way it gets written. This exact function is invoked from every one of PURCHASE_COST, OTHER_CAPITALIZED_COST, OPENING_WDV, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_METHOD and CAPITALIZATION_DATE (each column's item_change) so the figures update live while the user edits any of them; Transaction objects have no separate on-open/before-load recompute hook, so a record reopened untouched still shows the value as of its last save, not necessarily as of today's calendar date.
# business_logic: Recompute total accumulated depreciation (and its supporting total capitalized cost / residual value / opening accumulated depreciation) for Companies Act reporting

def run(args):
    # Step 1: Total capitalized cost
    purchase_cost = float(to_number(args.get('PURCHASE_COST')) or 0)
    other_cost = float(to_number(args.get('OTHER_CAPITALIZED_COST')) or 0)
    total_capitalized_cost = round(purchase_cost + other_cost, 2)

    # Step 2: Residual value from category percentage
    residual_pct = float(to_number(args.get('COMPANIES_ACT_RESIDUAL_VALUE_PCT')) or 0)
    companies_act_residual_value = round(total_capitalized_cost * residual_pct / 100, 2)

    # Step 3: Depreciable base
    depreciable_base = max(total_capitalized_cost - companies_act_residual_value, 0.0)

    # Step 4: Opening accumulated depreciation — derived from OPENING_WDV when present
    opening_wdv_raw = args.get('OPENING_WDV')
    if not_empty(opening_wdv_raw):
        opening_wdv = float(to_number(opening_wdv_raw) or 0)
        opening_accumulated_depreciation = round(
            max(min(total_capitalized_cost - opening_wdv, depreciable_base), 0.0), 2
        )
    else:
        opening_accumulated_depreciation = 0.0

    # Guard: cannot compute depreciation without life or capitalization date
    cap_date_raw = args.get('CAPITALIZATION_DATE')
    useful_life = float(to_number(args.get('COMPANIES_ACT_USEFUL_LIFE_YEARS')) or 0)

    if is_empty(cap_date_raw) or useful_life <= 0:
        return {
            'updates': {
                'total_capitalized_cost': total_capitalized_cost,
                'companies_act_residual_value': companies_act_residual_value,
                'opening_accumulated_depreciation': opening_accumulated_depreciation,
                'total_accumulated_depreciation': opening_accumulated_depreciation,
            }
        }

    cap_date = to_date(cap_date_raw)

    # Step 5: Effective end date — use approved disposal date when it predates today
    effective_end = today()
    asset_code = args.get('ASSET_CODE')
    if not_empty(asset_code):
        disposal_row = db.query_one(
            'SELECT DISPOSAL_DATE FROM ' + db.t('FAM_ASSET_DISPOSAL') +
            ' WHERE ASSET_CODE = :ac AND STATUS = :st',
            {'ac': asset_code, 'st': 'APPROVED'}
        )
        if disposal_row and not_empty(disposal_row.get('DISPOSAL_DATE')):
            disposal_date = to_date(disposal_row['DISPOSAL_DATE'])
            if disposal_date < effective_end:
                effective_end = disposal_date

    years_elapsed = max(days_between(cap_date, effective_end) / 365.25, 0.0)

    # Step 6: System depreciation by method
    method = args.get('COMPANIES_ACT_METHOD')
    system_dep = 0.0

    if method == 'SLM':
        system_dep = depreciable_base * min(years_elapsed, useful_life) / useful_life

    elif method == 'WDV':
        if total_capitalized_cost > 0:
            rv_ratio = companies_act_residual_value / total_capitalized_cost
            if rv_ratio <= 0.0:
                # Zero residual: cap WDV rate to avoid infinite depreciation
                r = 0.999
            elif rv_ratio >= 1.0:
                # Residual equals or exceeds cost: no depreciation
                r = 0.0
            else:
                r = 1.0 - rv_ratio ** (1.0 / useful_life)
            r = min(r, 0.999)
        else:
            r = 0.0
        system_dep = total_capitalized_cost - total_capitalized_cost * (1.0 - r) ** years_elapsed

    # Step 7: Total accumulated depreciation — capped at depreciable_base, floored at opening
    total_accumulated_depreciation = round(
        max(opening_accumulated_depreciation,
            min(opening_accumulated_depreciation + system_dep, depreciable_base)),
        2
    )

    return {
        'updates': {
            'total_capitalized_cost': total_capitalized_cost,
            'companies_act_residual_value': companies_act_residual_value,
            'opening_accumulated_depreciation': opening_accumulated_depreciation,
            'total_accumulated_depreciation': total_accumulated_depreciation,
        }
    }
