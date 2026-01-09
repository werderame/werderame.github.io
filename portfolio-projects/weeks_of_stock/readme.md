# Stock depletion projection (Weeks of Stock)

### Context
Supply chain teams need a single, consistent answer to: **“When will we run out, and where?”**
This project turns stock + inbound supply + demand into a forward-looking depletion timeline at a weekly grain.

---

## What decision this enables
- prioritize replenishment and transfers
- identify upcoming stock-outs early
- align ops + planning + finance around one auditable definition of “weeks of stock”

---

## Output (data contract)
**Grain:** `item_id × inventory_channel × year_week`

Key outputs:
- `remaining_stock` (capped at 0 for the “clean” series)
- `remaining_stock_negatives` (kept negative for diagnostics / variance analysis)
- `item_demand`
- `depletion_week` / `depletion_week_num`

---

## How it works (algorithm, not just SQL)
The core idea is a week-by-week stock balance:

**remaining_stock[t] = remaining_stock[t-1] + incoming_quantity[t] - item_demand[t]**

I implement this using a recursive CTE that:
1) anchors on the first demand week per SKU/channel
2) iterates forward week-by-week, carrying remaining stock
3) derives the depletion week as the last week where remaining_stock stays > 0

Model entrypoint:
- `rep_scm_stock_depletion_projection.sql`

Supporting models (inputs & prep):
- `int_scm_stock_for_weeks_of_stock_calculation.sql` (starting stock)
- `rep_scm_weeks_of_stock_ordered_demand.sql` (demand + inbound, ordered by week)
- `dim_date.sql` (week calendar alignment)

---

## Edge cases handled
- missing stock → defaults to 0, but still projects demand/inbound
- sparse demand weeks → ordered demand ensures deterministic iteration
- negative stock → retained in a diagnostic field (`remaining_stock_negatives`) and capped to 0 for stakeholder-facing series

---

## Data quality checks I would add in a full dbt project
- uniqueness: `(item_id, inventory_channel, year_week)` is unique
- not null: keys + week fields
- accepted values: inventory_channel enum
- sanity: remaining_stock is never negative in the “clean” series

---

## Files
- `rep_scm_stock_depletion_projection.sql` (flagship)
- `rep_scm_weeks_of_stock_kpi.sql` (final KPI)
- `rep_scm_weeks_of_stock_ordered_demand.sql` (demand/inbound prep)
- `int_scm_stock_for_weeks_of_stock_calculation.sql` (stock prep)

