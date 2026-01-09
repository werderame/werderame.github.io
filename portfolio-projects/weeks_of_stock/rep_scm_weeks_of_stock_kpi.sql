{{
        config(
            materialized='table'
            )
    }}

-- Sanitized portfolio example: weeks-of-stock KPI derived from depletion projection (dbt-style).

WITH
dim_date AS (
  SELECT
    yyyyww_iso
    , week_sequential_number
  FROM {{ ref('dim_date') }}
  WHERE the_day_of_week = 1 -- filter only one day of the week
)

, rep_scm_stock_depletion_projection AS (
  SELECT *
  FROM {{ ref('rep_scm_stock_depletion_projection') }}
)

, stock_lines AS (
  SELECT
    item_id
    , inventory_channel
    , year_week_number
    , week_sequential_number
    , remaining_stock
    , item_demand
    , incoming_quantity
    , depletion_week_sequential_number
    , demand_week_sequential_number
    , (depletion_week_sequential_number - demand_week_sequential_number) AS weeks_of_stock
    , demand_week_sequential_number AS start_seq
  FROM rep_scm_stock_depletion_projection
  WHERE depletion_order = 0 -- baseline line only
)

, short_stock AS (
  SELECT
    item_id
    , inventory_channel
    , start_seq
    , weeks_of_stock
  FROM stock_lines
  WHERE weeks_of_stock < 6 -- focus on items with short projected stock windows
)

, average_demand_def_1 AS (
  -- avg demand over the next 6 weeks
  -- since we need to include the baseline week (week 0) we need to union two queries:
  -- - baseline: avg demand over the next 6 weeks starting from the upcoming week
  -- - non-baseline: avg demand over the next 6 weeks starting from the current week
  SELECT
    base.item_id
    , base.inventory_channel
    , base.start_seq
    , AVG(proj.item_demand) AS avg_demand_6w_def_1
  FROM short_stock AS base
  INNER JOIN rep_scm_stock_depletion_projection AS proj
    ON proj.item_id = base.item_id
    AND proj.inventory_channel = base.inventory_channel
    AND proj.week_sequential_number > base.start_seq
    AND proj.week_sequential_number <= base.start_seq + 6
  GROUP BY
    base.item_id
    , base.inventory_channel
    , base.start_seq

  UNION ALL

  SELECT
    base.item_id
    , base.inventory_channel
    , base.start_seq + 1 AS start_seq
    , AVG(proj.item_demand) AS avg_demand_6w_def_1
  FROM short_stock AS base
  INNER JOIN rep_scm_stock_depletion_projection AS proj
    ON proj.item_id = base.item_id
    AND proj.inventory_channel = base.inventory_channel
    AND proj.week_sequential_number >= base.start_seq
    AND proj.week_sequential_number < base.start_seq + 6
  GROUP BY
    base.item_id
    , base.inventory_channel
    , base.start_seq + 1
)

, average_demand_def_2 AS (
  -- avg demand over the previous 4 weeks
  SELECT
    base.item_id
    , base.inventory_channel
    , base.start_seq
    , AVG(proj.item_demand) AS avg_demand_4w_def_2
  FROM short_stock AS base
  INNER JOIN rep_scm_stock_depletion_projection AS proj
    ON proj.item_id = base.item_id
    AND proj.inventory_channel = base.inventory_channel
    AND proj.week_sequential_number < base.start_seq
    AND proj.week_sequential_number >= base.start_seq - 4
  GROUP BY
    base.item_id
    , base.inventory_channel
    , base.start_seq
)

, kpi AS (
  SELECT
    s.item_id
    , s.inventory_channel
    , s.start_seq
    , s.weeks_of_stock
    , d1.avg_demand_6w_def_1
    , d2.avg_demand_4w_def_2
  FROM short_stock AS s
  LEFT JOIN average_demand_def_1 AS d1
    ON s.item_id = d1.item_id
    AND s.inventory_channel = d1.inventory_channel
    AND s.start_seq = d1.start_seq
  LEFT JOIN average_demand_def_2 AS d2
    ON s.item_id = d2.item_id
    AND s.inventory_channel = d2.inventory_channel
    AND s.start_seq = d2.start_seq
)

SELECT * FROM kpi -- noqa

