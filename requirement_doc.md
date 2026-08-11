## Asset Register
### Manage Asset Category Master
- Description: Maintain the classification of assets used to default useful life, depreciation method and applicable statutory rates on the Asset Register.
- Data points: CATEGORY_CODE, CATEGORY_NAME, PARENT_CATEGORY_CODE, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_DEFAULT_METHOD (SLM/WDV), COMPANIES_ACT_RESIDUAL_VALUE_PCT, INCOME_TAX_BLOCK_CODE (default), STATUS (Active/Inactive).
- Business rules: CATEGORY_CODE unique; COMPANIES_ACT_USEFUL_LIFE_YEARS > 0; COMPANIES_ACT_RESIDUAL_VALUE_PCT between 0 and 100; INCOME_TAX_BLOCK_CODE must exist in Income Tax Block Master.
- Business actions: Search, Add, Edit, Delete (only if unused), Activate/Deactivate.
- Additional data management: Deactivating a category blocks its use on new Asset Register entries but does not affect existing assets.

### Manage Vendor / Supplier Master
- Description: Maintain suppliers/vendors used for asset purchase, AMC and disposal transactions.
- Data points: VENDOR_CODE, VENDOR_NAME, VENDOR_TYPE (Supplier/AMC Provider/Buyer), GSTIN, ADDRESS, CONTACT_PERSON, PHONE, EMAIL, STATUS.
- Business rules: VENDOR_CODE unique; GSTIN format validation where provided.
- Business actions: Search, Add, Edit, Delete (only if unused), Activate/Deactivate.

### Create and Maintain Asset Register
- Description: Capture and maintain the complete statutory record of each fixed asset as required under the Companies Act, including identification, purchase and location details, from acquisition through its active life.
- Data points: ASSET_CODE (auto), ASSET_NAME, CATEGORY_CODE, SERIAL_NO, MAKE, MODEL, DESCRIPTION, ASSET_PHOTO, QR_CODE/BARCODE_TAG, BRANCH_CODE, LOCATION_CODE, DEPARTMENT_CODE, ASSIGNED_EMPLOYEE_CODE, VENDOR_NAME (free text), PURCHASE_INVOICE_NO, PURCHASE_DATE, PURCHASE_COST, OTHER_CAPITALIZED_COST (freight/installation/duties), TOTAL_CAPITALIZED_COST, CAPITALIZATION_DATE, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_METHOD (SLM/WDV), COMPANIES_ACT_RESIDUAL_VALUE, OPENING_WDV (user-entered written-down value of a legacy asset that already existed, with its own accumulated depreciation, before this system went live; blank for a fresh asset with no prior depreciation history), OPENING_ACCUMULATED_DEPRECIATION (system-computed, read-only = TOTAL_CAPITALIZED_COST − OPENING_WDV, or 0 when OPENING_WDV is blank), OPENING_WDV_AS_ON_DATE (the date, typically a financial-year-end, as of which OPENING_WDV/OPENING_ACCUMULATED_DEPRECIATION is stated for a legacy asset that existed before this system went live; blank for assets first capitalized and depreciated within this system), TOTAL_ACCUMULATED_DEPRECIATION (system-computed, read-only), INCOME_TAX_BLOCK_CODE, WARRANTY_START_DATE, WARRANTY_END_DATE, AMC_APPLICABLE (Y/N), STATUS (Draft/Pending Approval/Capitalized/Under Transfer/Disposed/Under Investigation), DISPOSAL_DATE (system-set, read-only; the date the asset was disposed, stamped when its Asset Sale/Scrap record is approved), LAST_VERIFIED_DATE (system-set, read-only; the date the asset was last physically verified, stamped from the line's VERIFIED_DATE when its Conduct Physical Verification cycle is approved), REMARKS.
- Business rules: SERIAL_NO unique within CATEGORY_CODE; TOTAL_CAPITALIZED_COST = PURCHASE_COST + OTHER_CAPITALIZED_COST; PURCHASE_COST > 0; CATEGORY_CODE, BRANCH_CODE, LOCATION_CODE, DEPARTMENT_CODE must exist in respective masters; VENDOR_NAME is free text with no master validation; CAPITALIZATION_DATE >= PURCHASE_DATE; core financial fields (PURCHASE_COST, CAPITALIZATION_DATE, CATEGORY_CODE, OPENING_WDV) locked once STATUS = Capitalized; asset becomes eligible for depreciation only after approval; OPENING_WDV_AS_ON_DATE is mandatory whenever OPENING_WDV is entered (> 0), and cannot be earlier than CAPITALIZATION_DATE; OPENING_ACCUMULATED_DEPRECIATION is derived automatically (not directly enterable) as GREATEST(LEAST(TOTAL_CAPITALIZED_COST − OPENING_WDV, depreciable base), 0) when OPENING_WDV is entered, else 0; TOTAL_ACCUMULATED_DEPRECIATION = OPENING_ACCUMULATED_DEPRECIATION + Companies Act depreciation accrued since CAPITALIZATION_DATE under COMPANIES_ACT_METHOD (SLM/WDV), clamped between OPENING_ACCUMULATED_DEPRECIATION and the depreciable base (TOTAL_CAPITALIZED_COST − COMPANIES_ACT_RESIDUAL_VALUE); recomputed live whenever PURCHASE_COST, OTHER_CAPITALIZED_COST, CAPITALIZATION_DATE, COMPANIES_ACT_USEFUL_LIFE_YEARS, COMPANIES_ACT_METHOD or OPENING_WDV is changed on the form.
- Business actions: Search, Add, Edit, Delete (Draft only), Submit-for-approval, Approve, Reject, Generate QR Code/Barcode Tag.
- Additional data management: On Approve, STATUS is set to Capitalized, ASSET_CODE is locked for depreciation processing, and the asset becomes visible in Locations & Assignment, Depreciation, Lifecycle and Verification activities.

## Locations & Assignment
### Manage Branch Master
- Description: Maintain the organisation's branches under which locations and departments are structured.
- Data points: BRANCH_CODE, BRANCH_NAME, ADDRESS, CITY, STATE, STATUS.
- Business rules: BRANCH_CODE unique.
- Business actions: Search, Add, Edit, Delete (only if unused), Activate/Deactivate.

### Manage Location Master
- Description: Maintain physical locations (building/floor/room/site) within a branch where assets are placed.
- Data points: LOCATION_CODE, LOCATION_NAME, BRANCH_CODE, ADDRESS/DESCRIPTION, STATUS.
- Business rules: LOCATION_CODE unique within BRANCH_CODE; BRANCH_CODE must exist in Branch Master.
- Business actions: Search, Add, Edit, Delete (only if unused), Activate/Deactivate.

### Manage Department Master
- Description: Maintain departments/cost centres to which assets and employees belong within a branch.
- Data points: DEPARTMENT_CODE, DEPARTMENT_NAME, BRANCH_CODE, COST_CENTRE_CODE, STATUS.
- Business rules: DEPARTMENT_CODE unique within BRANCH_CODE.
- Business actions: Search, Add, Edit, Delete (only if unused), Activate/Deactivate.

### Manage Employee Master (for Asset Assignment)
- Description: Maintain a lightweight employee directory used solely to assign custody of assets; not an authentication or HR record.
- Data points: EMPLOYEE_CODE, EMPLOYEE_NAME, BRANCH_CODE, DEPARTMENT_CODE, DESIGNATION, STATUS (Active/Inactive/Transferred).
- Business rules: EMPLOYEE_CODE unique; BRANCH_CODE and DEPARTMENT_CODE must exist in respective masters.
- Business actions: Search, Add, Edit, Delete (only if unused), Activate/Deactivate.
- Additional data management: Deactivating an employee flags any assets currently assigned to them for reassignment via Asset Transfer.

## Depreciation – Companies Act
### Manage Depreciation Rate Master – Companies Act
- Description: Maintain useful life, method and residual value norms per Schedule II of the Companies Act, 2013, by asset category.
- Data points: CATEGORY_CODE, USEFUL_LIFE_YEARS, METHOD (SLM/WDV), RESIDUAL_VALUE_PCT, EFFECTIVE_FROM_DATE.
- Business rules: One active rate record per CATEGORY_CODE at a time; RESIDUAL_VALUE_PCT between 0 and 100; USEFUL_LIFE_YEARS > 0.
- Business actions: Search, Add, Edit, Delete (only if unused).

### Generate Depreciation – Companies Act (Monthly)
- Description: Compute pro-rata monthly depreciation for all capitalized assets as per Schedule II (SLM/WDV), accounting for additions, transfers and disposals occurring during the period; review and post to the books.
- Data points (criteria): FINANCIAL_YEAR, PERIOD_MONTH, BRANCH_CODE (optional). Data points (generated lines): ASSET_CODE, ASSET_NAME, CATEGORY_CODE, OPENING_WDV, ADDITIONS_DURING_MONTH, DISPOSALS_DURING_MONTH, DEPRECIATION_METHOD, MONTHLY_DEPRECIATION_AMOUNT, CLOSING_WDV, ACCUMULATED_DEPRECIATION, ADJUSTMENT_REMARKS.
- Business rules: Depreciation computed from CAPITALIZATION_DATE (or Installation Date if later) on a pro-rata daily/monthly basis; for a legacy asset carrying an OPENING_WDV_AS_ON_DATE, processing starts only from the day after that date instead of the capitalization date, and OPENING_WDV for the first period processed after that date = TOTAL_CAPITALIZED_COST − OPENING_ACCUMULATED_DEPRECIATION (rather than assuming no prior depreciation); such a resumed asset is not counted as a fresh addition in that month. Depreciation stops in the month of disposal per DISPOSAL_DATE; CLOSING_WDV cannot go below RESIDUAL_VALUE; the process runs one FINANCIAL_YEAR/PERIOD_MONTH at a time (month-wise only, no ranges); a period already Approved & Posted for an asset cannot be regenerated — attempting to do so is blocked with an error.
- Business actions: Generate (preview), Edit (adjustment column only), Submit-for-approval, Approve & Post, Cancel, Close Financial Year (locks all 12 posted periods and rolls forward yearly closing WDV as next year's opening WDV).
- Additional data management: On Approve & Post, ACCUMULATED_DEPRECIATION and current WDV on the Asset Register are updated and become the OPENING_WDV for the next period; posted data feeds the Depreciation Register (R).

## Depreciation – Income Tax
### Manage Depreciation Rate Master – Income Tax
- Description: Maintain block-of-assets rates as prescribed under the Income Tax Act/Rules.
- Data points: BLOCK_CODE, BLOCK_DESCRIPTION, RATE_PCT, EFFECTIVE_FROM_DATE.
- Business rules: One active rate per BLOCK_CODE at a time; RATE_PCT between 0 and 100.
- Business actions: Search, Add, Edit, Delete (only if unused).

### Generate Depreciation – Income Tax (Annual)
- Description: Compute block-wise Written Down Value depreciation for the Assessment Year as per the Income Tax Act, applying the 180-day usage rule for additions and reducing the block for disposals.
- Data points (criteria): ASSESSMENT_YEAR, BLOCK_CODE (optional), BRANCH_CODE (optional). Data points (generated lines): BLOCK_CODE, BLOCK_DESCRIPTION, OPENING_WDV, ADDITIONS_180_DAYS_OR_MORE, ADDITIONS_LESS_THAN_180_DAYS, DISPOSALS_DURING_YEAR, RATE_PCT, DEPRECIATION_AMOUNT, CLOSING_WDV.
- Business rules: **180-Day Rule (Section 32, Income Tax Act):** New assets are classified by their put-to-use date within the assessment year (April 1 – March 31). If PUT_TO_USE_DATE (from the Installation record, or CAPITALIZATION_DATE if no installation record exists) falls on or before 3 October of that financial year, the asset qualifies for the full depreciation rate (ADDITIONS_180_DAYS_OR_MORE bucket). If PUT_TO_USE_DATE is after 3 October, only 50% of the normal depreciation rate applies (ADDITIONS_LESS_THAN_180_DAYS bucket). Assets already in the opening block always attract the full rate.

  **Computation:**
  - NET_BLOCK = OPENING_WDV + ADDITIONS_180_DAYS_OR_MORE + ADDITIONS_LESS_THAN_180_DAYS − DISPOSALS_DURING_YEAR (disposal value = sale proceeds or insurance proceeds, whichever is applicable).
  - If NET_BLOCK ≤ 0: DEPRECIATION_AMOUNT = 0; the positive excess (|NET_BLOCK|) is flagged as short-term capital gain (STCG) in REMARKS; CLOSING_WDV = 0.
  - If NET_BLOCK > 0: DEPRECIATION_AMOUNT = max(0, OPENING_WDV + ADDITIONS_180_DAYS_OR_MORE − DISPOSALS_DURING_YEAR) × RATE_PCT + ADDITIONS_LESS_THAN_180_DAYS × (RATE_PCT × 50%), capped at NET_BLOCK. CLOSING_WDV = NET_BLOCK − DEPRECIATION_AMOUNT.

  Other rules: RATE_PCT sourced from FAM_DEP_RATE_IT_MASTER for the applicable BLOCK_CODE and ASSESSMENT_YEAR (EFFECTIVE_FROM_DATE ≤ start of FY, latest active row). One output row per BLOCK_CODE (per BRANCH_CODE when filtered). Period cannot be re-generated once posted. For a block that already existed (with its own pooled WDV) before this system went live, FAM_DEP_RATE_IT_MASTER's OPENING_WDV/OPENING_WDV_AS_ON_DATE fields seed that block's OPENING_WDV for the first Assessment Year processed after that date (0 for any earlier year or a block with no legacy data).
- Business actions: Generate (preview), Edit (adjustment column only), Submit-for-approval, Approve & Post, Cancel.
- Additional data management: On Approve & Post, block-wise closing WDV is stored as next year's opening WDV and feeds the Depreciation Register (R) for the Income Tax view.

### Generate Income Tax Depreciation – Asset Ledger (Form 3CD Clause 18)
- Description: Allocate each Income Tax block's already-computed annual depreciation across its member assets, purely for Tax Audit Form 3CD Clause 18 asset-level disclosure; does not alter the statutory block-level computation.
- Data points (criteria): ASSESSMENT_YEAR, BLOCK_CODE (optional), BRANCH_CODE (optional). Data points (generated lines): ASSET_CODE, ASSET_NAME, BLOCK_CODE, BLOCK_DESCRIPTION, RATE_CATEGORY (ADDITION_FULL_RATE/ADDITION_HALF_RATE/OPENING_BLOCK_MEMBER/DISPOSED/NOT_ELIGIBLE), GROSS_BLOCK, OPENING_WDV_ALLOCATED, DEPRECIATION_ALLOCATED, CLOSING_WDV_ALLOCATED, REMARKS.
- Business rules: Income Tax law computes depreciation at BLOCK level only, so this process re-derives the same block-wise figures as the Income Tax annual process and allocates each block's DEPRECIATION_AMOUNT across its member assets in proportion to each asset's own weight (its full cost for a full-rate addition, half cost for a half-rate addition, or its own legacy opening-WDV seed for a pre-existing opening-block member; 0 for an asset disposed during the year) as a share of the block's total weight; satisfies Form 3CD Clause 18's asset-wise depreciation particulars. Runs one ASSESSMENT_YEAR at a time (year-wise only, no ranges); an asset already Approved & Posted for an assessment year cannot be regenerated for that year — attempting to do so is blocked with an error.
- Business actions: Generate (preview), Edit (remarks/status only), Submit-for-approval, Approve & Post, Cancel.
- Additional data management: On Approve & Post, each asset's closing allocated WDV is stored as next year's opening allocated WDV; posted data feeds the Depreciation Register (R) / Form 3CD Clause 18 disclosure.

## Asset Lifecycle
### Record Asset Installation
- Description: Record and confirm the date and details of physical installation/commissioning of a capitalized asset at its assigned location, marking the point from which the asset is put to use.
- Data points: ASSET_CODE, INSTALLATION_DATE, INSTALLED_BY, INSTALLATION_LOCATION_CONFIRMED (Y/N), INSTALLATION_CERTIFICATE_ATTACHMENT, REMARKS, STATUS (Pending/Confirmed).
- Business rules: ASSET_CODE must be in Capitalized status; INSTALLATION_DATE >= CAPITALIZATION_DATE; an asset can have only one active installation record.
- Business actions: Search, Add, Edit (Pending only), Submit-for-approval, Approve, Cancel.
- Additional data management: On Approve, Asset Register PUT_TO_USE_DATE is set to INSTALLATION_DATE and used as the depreciation start date where later than the capitalization date.

### Asset Transfer
- Description: Record and process the movement of an asset from one branch/location/department/employee to another.
- Data points: TRANSFER_NO (auto), TRANSFER_DATE, ASSET_CODE, FROM_BRANCH_CODE, FROM_LOCATION_CODE, FROM_DEPARTMENT_CODE, FROM_EMPLOYEE_CODE, TO_BRANCH_CODE, TO_LOCATION_CODE, TO_DEPARTMENT_CODE, TO_EMPLOYEE_CODE, TRANSFER_REASON, STATUS (Draft/Pending Approval/Approved/Cancelled).
- Business rules: TO location/department/employee combination must differ from FROM; ASSET_CODE must be in Capitalized/Active status; FROM values default from and must match the asset's current location.
- Business actions: Search, Add, Edit (Draft only — a non-Draft transfer can still be opened and viewed, it just becomes fully read-only/locked from further edits), Submit-for-approval, Approve, Cancel.
- Compact list view: the mobile/card list shows Transfer No, Status, Asset Name, From Branch, From Location, To Branch and To Location.
- Additional data management: On Approve, Asset Register current BRANCH_CODE/LOCATION_CODE/DEPARTMENT_CODE/ASSIGNED_EMPLOYEE_CODE are updated to the TO values and asset transfer history is retained for audit.

### Asset Sale / Scrap
- Description: Record the disposal of an asset by sale or scrap and remove it from the active Asset Register on approval, computing profit/loss on disposal.
- Data points: DISPOSAL_NO (auto), DISPOSAL_DATE, ASSET_CODE, DISPOSAL_TYPE (Sale/Scrap), SALE_VALUE, BUYER_OR_SCRAP_VENDOR_CODE, NET_BOOK_VALUE_AS_ON_DISPOSAL (computed), PROFIT_LOSS_ON_DISPOSAL (computed), DISPOSAL_REASON, STATUS (Draft/Pending Approval/Approved/Cancelled).
- Business rules: ASSET_CODE must not already be Disposed; DISPOSAL_DATE >= CAPITALIZATION_DATE; PROFIT_LOSS_ON_DISPOSAL = SALE_VALUE − NET_BOOK_VALUE_AS_ON_DISPOSAL; SALE_VALUE mandatory when DISPOSAL_TYPE = Sale.
- Business actions: Search, Add, Edit (Draft only), Submit-for-approval, Approve, Cancel.
- Additional data management: On Approve, Asset Register STATUS is set to Disposed and Asset Register DISPOSAL_DATE is set to this record's DISPOSAL_DATE, the asset is excluded from future Companies Act and Income Tax depreciation generation, and it is removed from the block of assets (Income Tax) from the next generation run.

## Physical Verification
### Conduct Physical Verification
- Description: Plan and execute periodic physical confirmation of assets at a branch/location, capturing findings against the Asset Register and resolving discrepancies.
- Data points (header): VERIFICATION_CYCLE_NO (auto), VERIFICATION_DATE, BRANCH_CODE, LOCATION_CODE, VERIFIER_EMPLOYEE_CODE, STATUS (Planned/In Progress/Pending Approval/Closed). Data points (lines): ASSET_CODE, EXPECTED_LOCATION_CODE, EXPECTED_EMPLOYEE_CODE, PHYSICAL_STATUS_FOUND (Found/Not Found/Damaged/Extra-Unregistered), VERIFIED_DATE, REMARKS, ASSET_PHOTO_URL (optional photo evidence of the asset's physical condition/location captured during verification; image upload with a thumbnail shown in the line list).
- Business rules: Line items default from all Capitalized assets in the selected BRANCH_CODE/LOCATION_CODE; the line's ASSET_CODE picker is restricted to assets belonging to the header's BRANCH_CODE; each ASSET_CODE can appear once per cycle; cycle cannot close while any line is unverified; the header and all line rows can only be added, edited or deleted while the cycle STATUS is Planned or In Progress — once the cycle is submitted for approval, approved (Closed) or cancelled, the cycle and its lines become view-only.
- Business actions: Search, Add cycle, Scan QR code/Barcode to confirm asset, Mark Found/Not Found/Damaged, Submit-for-approval, Approve, Cancel.
- Additional data management: On Approve, every line carrying a VERIFIED_DATE updates the Asset Register's LAST_VERIFIED_DATE for that asset; assets marked Not Found update Asset Register STATUS to Under Investigation; assets marked Damaged raise a remark flag for follow-up; approved cycle data feeds the Verification Report (R).

## Warranty & AMC
### Manage Warranty Details
- Description: Record and update the manufacturer/vendor warranty coverage of an asset for tracking validity.
- Data points: ASSET_CODE, WARRANTY_PROVIDER_VENDOR_CODE, WARRANTY_START_DATE, WARRANTY_END_DATE, WARRANTY_TERMS, WARRANTY_DOCUMENT_ATTACHMENT.
- Business rules: WARRANTY_END_DATE > WARRANTY_START_DATE; ASSET_CODE must exist and be Capitalized.
- Business actions: Search, Add, Edit.
- Additional data management: Warranty validity feeds the Warranty / AMC Expiry (V).

### Manage AMC Contracts
- Description: Record and track Annual Maintenance Contracts covering one or more assets, including validity and renewal.
- Data points (header): AMC_CONTRACT_NO (auto), AMC_VENDOR_CODE, START_DATE, END_DATE, CONTRACT_COST, STATUS (Active/Expired/Renewed/Cancelled), PREVIOUS_CONTRACT_NO (for renewals). Data points (lines): ASSET_CODE, ASSET_NAME, COVERAGE_REMARKS.
- Business rules: END_DATE > START_DATE; each line ASSET_CODE must be Capitalized; renewal creates a new AMC_CONTRACT_NO linked to PREVIOUS_CONTRACT_NO and sets the prior contract to Renewed.
- Business actions: Search, Add, Edit, Renew, Submit-for-approval, Approve, Expire, Cancel. Approve can be run directly on a Draft contract (Submit-for-approval to Pending Approval first is optional, not mandatory). Edit is only available while a contract is Draft. Expire is a manual action, available only on an Active contract whose END_DATE has already passed, that sets STATUS = Expired (status does not change automatically with the passage of time).
- Additional data management: On Approve, covered assets are flagged AMC_APPLICABLE = Y on the Asset Register; contract validity feeds the Warranty / AMC Expiry (V).
- Trigger: send-notification to the asset owner/branch when Warranty or AMC coverage is within 30 days of WARRANTY_END_DATE/END_DATE.

## Asset Register Report (R)
- Layout: Statutory asset register grouped by CATEGORY_CODE, then LOCATION_CODE.
- Criteria: BRANCH_CODE, LOCATION_CODE, CATEGORY_CODE, STATUS, AS_ON_DATE.
- Grouping/Totals: Sub-total of TOTAL_CAPITALIZED_COST per category and per location; grand total for the selected criteria.
- Columns: ASSET_CODE, ASSET_NAME, SERIAL_NO, MAKE, MODEL, LOCATION_CODE, DEPARTMENT_CODE, ASSIGNED_EMPLOYEE_CODE, PURCHASE_DATE, VENDOR_CODE, TOTAL_CAPITALIZED_COST, STATUS.
- Footer: Signature block for Finance Head / Preparer.

## Depreciation Register (R)
- Layout: Statutory depreciation register, toggled between Companies Act (Schedule II, grouped by CATEGORY_CODE) and Income Tax (grouped by BLOCK_CODE).
- Criteria: METHOD_TOGGLE (Companies Act/Income Tax), FINANCIAL_YEAR or ASSESSMENT_YEAR, PERIOD_MONTH (Companies Act only), BRANCH_CODE.
- Grouping/Totals: Sub-total of depreciation and closing WDV per category/block; grand total for the period.
- Columns: ASSET_CODE or BLOCK_CODE, OPENING_WDV, ADDITIONS, DISPOSALS, DEPRECIATION_FOR_PERIOD, CLOSING_WDV, ACCUMULATED_DEPRECIATION.
- Footer: Signature block for CFO / Statutory Auditor.

## Asset Depreciation Reconciliation (D)
- Purpose: Per-asset drill-down showing period-wise depreciation under both Companies Act and Income Tax side by side, for finance reconciliation between the two bases.
- Criteria: ASSET_CODE (lookup, single asset).
- Panel 1 — Companies Act (real, per-asset): every generated period for the selected asset from the Generate Depreciation - Companies Act process — OPENING_WDV, ADDITIONS_DURING_MONTH, DISPOSALS_DURING_MONTH, DEPRECIATION_METHOD, MONTHLY_DEPRECIATION_AMOUNT, CLOSING_WDV, ACCUMULATED_DEPRECIATION, STATUS.
- Panel 2 — Income Tax (block-level context): since Income Tax depreciation is computed per BLOCK_CODE (not per asset) under the Income Tax Act, this panel shows every generated assessment year for the block the selected asset belongs to (via its INCOME_TAX_BLOCK_CODE) — BLOCK's OPENING_WDV, ADDITIONS_180_DAYS_OR_MORE, ADDITIONS_LESS_THAN_180_DAYS, DISPOSALS_DURING_YEAR, RATE_PCT, DEPRECIATION_AMOUNT, CLOSING_WDV, STATUS — clearly labeled as block-level, plus one estimated column allocating the block's DEPRECIATION_AMOUNT to this asset pro-rata by its share of the block's capitalized cost, so it can be compared against Panel 1's figure. This allocation is explicitly an estimate, not a statutory per-asset amount.
- Both panels populate only once the corresponding Generate + Approve & Post cycle has been run for that period/year; empty until then.

## Verification Report (R)
- Layout: Physical verification confirmation document, grouped by LOCATION_CODE.
- Criteria: VERIFICATION_CYCLE_NO, BRANCH_CODE, LOCATION_CODE, VERIFICATION_DATE range.
- Grouping/Totals: Count of assets by PHYSICAL_STATUS_FOUND per location; grand total count of assets verified.
- Columns: ASSET_CODE, ASSET_NAME, EXPECTED_LOCATION_CODE, PHYSICAL_STATUS_FOUND, REMARKS, VERIFIED_DATE.
- Footer: Signature blocks for Verifier and Approver.

## Asset Verification Coverage by Category (V)
- Visualization: Grid, one row per Asset Category.
- Purpose: shows what proportion of each category's in-service assets have actually been physically verified within a chosen recent period.
- Criteria: Asset Category (optional, lookup to Asset Category Master, defaults to all categories); Verification Period From date (defaults to 12 months before today — the upper bound is always the current date).
- Columns: CATEGORY_NAME, TOTAL_ASSETS (count of Asset Register rows in that category with STATUS = Active), VERIFIED_ASSETS (of those, the count with at least one Physical Verification line whose VERIFIED_DATE falls within the selected period), PCT_VERIFIED (VERIFIED_ASSETS / TOTAL_ASSETS, 0 when the category has no active assets).

## Warranty / AMC Expiry (V)
- Visualization: Grid.
- Criteria: BRANCH_CODE, LOCATION_CODE, TYPE (Warranty/AMC), EXPIRY_DATE range, STATUS.
- Data points: ASSET_CODE, ASSET_NAME, TYPE, PROVIDER_VENDOR_CODE, START_DATE, END_DATE, DAYS_TO_EXPIRY, STATUS.
- Drill-down: Clicking an ASSET_CODE opens the Asset Register detail for that asset.

## Assets Not Under AMC (V)
- Visualization: Grid over the Asset Register.
- Purpose: lists assets that are NOT currently covered by any AMC contract (AMC_APPLICABLE flag is not 'Y').
- Criteria: Asset Category (optional, lookup to Asset Category Master, defaults to all categories); Branch (optional, lookup to Branch Master, defaults to all branches).
- Columns: ASSET_CODE, ASSET_NAME, CATEGORY_NAME, BRANCH_NAME, STATUS, MAKE, MODEL, PURCHASE_DATE, PURCHASE_COST.

## AMC Coverage & Expiry (V)
- Visualization: Grid joining AMC Contracts -> AMC Contract Line -> Asset Register.
- Purpose: shows AMC contract details together with each covered asset, restricted to coverage that has already expired or will expire by a selected date.
- Criteria: Expiring On or Before (date, defaults to today) filters to contract lines whose END_DATE <= this date; Branch (optional, lookup to Branch Master, defaults to all branches).
- Columns: AMC_CONTRACT_NO, AMC_VENDOR_CODE, START_DATE, END_DATE, CONTRACT STATUS, ASSET_CODE, ASSET_NAME, BRANCH_NAME, CATEGORY_NAME, DAYS_TO_EXPIRY, EXPIRY_INDICATOR.
- Sort: END_DATE ascending (most overdue / soonest expiring first).

## Asset Movement History (V)
- Visualization: Grid, one row per transfer/movement event, sorted asset-wise then chronologically (TRANSFER_DATE ascending) so it reads as a per-asset movement trail.
- Source: FAM_ASSET_TRANSFER joined to FAM_ASSET_REGISTER (for CATEGORY_NAME) and FAM_ASSET_CATEGORY_MASTER.
- Criteria: ASSET_CODE (optional lookup — pick one specific asset), CATEGORY_CODE (optional lookup — see a whole category's movement history), STATUS (defaults to APPROVED, since only Approved transfers are actual completed physical moves; can be broadened to Draft/Pending Approval/Cancelled).
- Columns: ASSET_CODE, ASSET_NAME, CATEGORY_NAME, TRANSFER_NO, TRANSFER_DATE, STATUS, FROM_BRANCH_NAME, FROM_LOCATION_NAME, FROM_DEPARTMENT_NAME, FROM_EMPLOYEE_NAME, TO_BRANCH_NAME, TO_LOCATION_NAME, TO_DEPARTMENT_NAME, TO_EMPLOYEE_NAME, TRANSFER_REASON.

## Management Dashboard (D)
- Role: Asset / Finance Manager.
- Criteria: FINANCIAL_YEAR (default current FY), BRANCH_CODE (default: logged-in user's branch, selectable All).
- Visuals:
  - Total Gross Asset Value (Card with sparkline) — trend of TOTAL_CAPITALIZED_COST over the FY.
  - Total Net Book Value (Card) — sum of CLOSING_WDV as on the latest posted period.
  - Assets Pending Approval (Card) — count of Asset Register/Transfer/Disposal/Depreciation records in Pending Approval status.
  - Warranty/AMC Expiring in 30 Days (Card) — count from Warranty/AMC records; drills through to Warranty / AMC Expiry (V).
  - Asset Value by Category (Doughnut-Chart) — TOTAL_CAPITALIZED_COST by CATEGORY_CODE; drills through to Asset Register Report (R) filtered by category.
  - Asset Count by Location (Column-Chart) — asset count by LOCATION_CODE; drills through to Asset Register Report (R) filtered by location.
  - Monthly Depreciation Trend – Companies Act (Line-Chart) — MONTHLY_DEPRECIATION_AMOUNT by PERIOD_MONTH; drills through to Depreciation Register (R), Companies Act view.
  - Depreciation Comparison – Companies Act vs Income Tax (Stacked-Column-Chart) — depreciation amount by month/year and method; drills through to Depreciation Register (R).
  - Physical Verification Status (Pie-Chart) — count by PHYSICAL_STATUS_FOUND for the latest verification cycle; drills through to Verification Report (R).
  - Asset Disposal Value – Sale vs Scrap (Waterfall) — PROFIT_LOSS_ON_DISPOSAL bridge for the FY; drills through to Asset Register Report (R) filtered to disposed assets.
  - Monthly Depreciation Posting Compliance (Gauge vs 100% target) — percentage of eligible assets with current-period depreciation posted.