{{
    config(
        materialized = 'table'
        )
}}

-- Sanitized portfolio example: stock depletion projection using recursive SQL (dbt-style).

WITH
-- stock layer.
int_scm_stock_for_weeks_of_stock_calculation AS (
  SELECT *
  FROM {{ ref('int_scm_stock_for_weeks_of_stock_calculation') }}
)

-- calendar layer
, dim_date AS (
  SELECT DISTINCT
    yyyyww_iso
    , week_sequential_number
    , the_day_of_week
  FROM {{ ref('dim_date') }}
  WHERE the_day_of_week = 1 -- filter only one day of the week
)

-- calculation layer
-- 1. order demand
, ordered_demand AS ( -- order demand data for depletion calculation
  SELECT * FROM {{ ref('rep_scm_weeks_of_stock_ordered_demand') }}
)

-- master data
, dim_released_items AS (
  SELECT
    item_id
    , planning_category
  FROM {{ ref('dim_released_items') }}
)

-- Baseline: one row per key at depletion_order = 0, aligned to the starting week
, initial_stock AS (
  SELECT
    demand.item_id
    , demand.inventory_channel
    , 0 AS depletion_order
    , demand.year_week AS year_week
    , demand.year_week_number AS year_week_number
    , demand.week_sequential_number AS week_sequential_number
    , 0 AS item_demand
    , COALESCE(stock.stock_quantity, 0) AS remaining_stock
    , COALESCE(stock.stock_quantity, 0) AS remaining_stock_negatives
    , 0 AS incoming_quantity
  FROM ordered_demand AS demand
  LEFT JOIN int_scm_stock_for_weeks_of_stock_calculation AS stock
    ON demand.item_id = stock.item_id
    AND demand.inventory_channel = stock.inventory_channel
  WHERE demand.depletion_order = 1
)

-- 2. display recursive stock depletion
-- recursion: remaining = prev_remaining + incoming - demand
-- get the stock, deplete the demand, calculate the remaining stock, thus use this as the stock for the next week
, recursive_stock AS ( -- anchor
  SELECT
    demand.item_id
    , demand.inventory_channel
    , demand.depletion_order
    , demand.year_week
    , demand.year_week_number
    , demand.week_sequential_number
    , demand.item_demand
    , COALESCE(stock.stock_quantity, 0) + demand.incoming_quantity - demand.item_demand AS remaining_stock
    , COALESCE(stock.stock_quantity, 0) + demand.incoming_quantity - demand.item_demand AS remaining_stock_negatives
    , demand.incoming_quantity
  FROM ordered_demand AS demand
  LEFT JOIN int_scm_stock_for_weeks_of_stock_calculation AS stock
    ON demand.item_id = stock.item_id
    AND demand.inventory_channel = stock.inventory_channel
  WHERE demand.depletion_order = 1

  UNION ALL

  SELECT
    demand.item_id
    , demand.inventory_channel
    , demand.depletion_order
    , demand.year_week
    , demand.year_week_number
    , demand.week_sequential_number
    , demand.item_demand
    , GREATEST(prev.remaining_stock + demand.incoming_quantity - demand.item_demand, 0) AS remaining_stock
    , prev.remaining_stock_negatives + demand.incoming_quantity - demand.item_demand AS remaining_stock_negatives
    , demand.incoming_quantity
  FROM ordered_demand AS demand
  INNER JOIN recursive_stock AS prev
    ON demand.item_id = prev.item_id
    AND demand.inventory_channel = prev.inventory_channel
    AND demand.depletion_order = prev.depletion_order + 1
)

-- 3. union baseline + recursion
, stock_depletion_union AS (
  SELECT * FROM initial_stock
  UNION ALL
  SELECT * FROM recursive_stock
)

-- 4. identify depletion week: first week where remaining hits 0 (or the last positive week)
, depletion_week AS (
  SELECT
    item_id
    , inventory_channel
    , MIN(year_week_number) AS depletion_week_numeric
  FROM (
    SELECT
      item_id
      , inventory_channel
      , year_week_number
      , remaining_stock
      , LAG(remaining_stock) OVER (
          PARTITION BY item_id, inventory_channel
          ORDER BY year_week_number
        ) AS remaining_stock_prev
    FROM stock_depletion_union
    WHERE depletion_order > 0
  ) s
  WHERE remaining_stock = 0 AND COALESCE(remaining_stock_prev, 1) > 0
  GROUP BY item_id, inventory_channel
)

-- final presentation layer
, final AS (
  SELECT
    stock.item_id
    , stock.inventory_channel
    , stock.depletion_order
    , stock.year_week
    , stock.year_week_number
    , stock.week_sequential_number
    , stock.item_demand
    , stock.incoming_quantity
    , stock.remaining_stock
    , stock.remaining_stock_negatives
    , depletion.depletion_week_numeric
    , cal_depletion.week_sequential_number AS depletion_week_sequential_number
    , cal_demand.week_sequential_number AS demand_week_sequential_number
    , item_data.planning_category
  FROM stock_depletion_union AS stock
    LEFT JOIN depletion_week AS depletion
      ON
        stock.item_id = depletion.item_id
        AND stock.inventory_channel = depletion.inventory_channel
    INNER JOIN dim_date AS cal_depletion
      ON depletion.depletion_week_numeric = cal_depletion.yyyyww_iso
    INNER JOIN dim_date AS cal_demand
      ON stock.year_week_number = cal_demand.yyyyww_iso
    LEFT JOIN dim_released_items AS item_data
      ON stock.item_id = item_data.item_id
)

-- work around sqlfluff / linting parsing edge-cases
SELECT * FROM final -- noqa
