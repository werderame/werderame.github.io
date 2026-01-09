{{
    config(
        materialized = 'table'
        )
}}

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
    , week_sequential_number -- sequential are used for calculating time distances
  FROM {{ ref('dim_date') }}
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
    , LEFT(stock.current_yearweek_iso, 4) || '_CW' || RIGHT(stock.current_yearweek_iso, 2) AS year_week
    , stock.current_yearweek_iso AS year_week_number
    , NULL AS item_demand
    , COALESCE(stock.stock_quantity, 0) AS remaining_stock
  FROM ordered_demand AS demand

    LEFT JOIN int_scm_stock_for_weeks_of_stock_calculation AS stock
      ON
        demand.item_id = stock.item_id
        AND demand.inventory_channel = stock.inventory_channel
  WHERE demand.depletion_order = 1 -- only select the first iteration of the key (item and inventory channel)

)

-- 2. display recursive stock depletion
-- recursion: remaining = prev_remaining + incoming - demand
-- get the stock, deplete the demannd, calculate the remaining stock, thus use this as the stock for the next week
, recursive_stock AS ( -- anchor
  SELECT
    demand.item_id
    , demand.inventory_channel
    , demand.depletion_order
    , demand.year_week
    , demand.year_week_number
    , demand.week_sequential_number
    , demand.item_demand
    , COALESCE(stock.stock_quantity, 0) + demand.incoming_quantity - demand.item_demand AS remaining_stock -- calculate the remaining stock
  FROM ordered_demand AS demand

    INNER JOIN int_scm_stock_for_weeks_of_stock_calculation AS stock
      ON
        demand.item_id = stock.item_id -- stock and demand per article
        AND demand.inventory_channel = stock.inventory_channel

  WHERE demand.depletion_order = 1 -- join on week 1

  UNION ALL

  SELECT -- recursive step: go to next row
    demand.item_id
    , demand.inventory_channel
    , demand.depletion_order
    , demand.year_week
    , demand.year_week_number
    , demand.week_sequential_number
    , demand.item_demand
    , recur.remaining_stock + demand.incoming_quantity - demand.item_demand AS remaining_stock
  FROM recursive_stock AS recur

    INNER JOIN ordered_demand AS demand
      ON
        demand.item_id = recur.item_id -- join on the item
        AND demand.inventory_channel = recur.inventory_channel -- and on the distribution center
        AND demand.depletion_order = recur.depletion_order + 1 -- on the next row
)

, clean_zero_stock AS ( -- output the clean version of the stock projection
  SELECT
    item_id
    , inventory_channel
    , depletion_order
    , year_week
    , year_week_number
    , item_demand
    , remaining_stock AS remaining_stock_negatives -- renaming to explicate that this stock allows negative numbers
    , IFF(remaining_stock < 0, 0, remaining_stock) AS remaining_stock
  FROM recursive_stock

  UNION ALL

  -- baseline rows at depletion_order = 0 (previous week of first demand)
  SELECT
    item_id
    , inventory_channel
    , depletion_order
    , year_week
    , year_week_number
    , item_demand
    , remaining_stock AS remaining_stock_negatives
    , IFF(remaining_stock < 0, 0, remaining_stock) AS remaining_stock
  FROM initial_stock

)

-- 3. calculate depletion week,
, depletion_week AS ( -- calculate the depletion week
  SELECT
    item_id
    , inventory_channel
    , MAX(year_week) AS depletion_week
    , MAX(year_week_number) AS depletion_week_numeric
  FROM clean_zero_stock

  WHERE remaining_stock > 0 -- get the latest row per item with some remaining stock

  GROUP BY ALL
)

-- 4. calculate weeks of stock
, final AS ( -- join together the stock depletion data and calculate the weeks of stock
  SELECT
    stock.*
    , item_data.planning_category
    , depletion.depletion_week
    , cal_depletion.week_sequential_number - cal_demand.week_sequential_number AS weeks_of_stock_negatives
    , GREATEST(cal_depletion.week_sequential_number - cal_demand.week_sequential_number, 0) AS weeks_of_stock
  FROM clean_zero_stock AS stock

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

-- work around the sqlfluff issue
SELECT * FROM final -- noqa: disable=Enpal_L002
