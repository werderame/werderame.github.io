/*
All references to business categories, distribution centers and any other propriety information has been masked or randomized
*/

/*
Snapshots are taken at 23:45 once a day
FI has a live inventory, therefore each night's snapshot represents the opening stock of the next day.
PI has weekly cleardown, therefore each Friday's snapshot represents the opening stock of the week staring on Saturday. It will make sense to take
another snapshot after cleardown the next week, to get an accurate Saturday starting stock. And so on, on a weekly basis.
*/

WITH 

----------------- Prep INVENTORY source
latest_snapshot AS (
    SELECT
        *,
        -- FI will have daily snapshot and PI will have Friday snapshots
        DENSE_RANK() OVER (PARTITION BY dc_code ORDER BY snapshot_imported_at DESC) AS row_number,
        DENSE_RANK() OVER (PARTITION BY dc_code ORDER BY
            CASE
                WHEN dc_code = 'PI' AND EXTRACT(DOW FROM TO_DATE(snapshot_imported_at, 'yyyyMMdd')) = 6 THEN snapshot_imported_at
                ELSE NULL
            END DESC) AS row_number_ve,
        CASE  -- Discardment date calculated based on category: C_5 = 0 ACL, C_7 and other categories = 5 ACL.
            WHEN LEFT(sku_code, 3) = 'C_5' THEN expiration_time::DATE
            ELSE (expiration_time::DATE - INTERVAL '4 days')
        END as discardment_date
    FROM
        inventory.snapshot_history
    WHERE 1=1
        AND dc_code IN ('FI', 'PI')
        AND LEFT(sku_code, 3) IN ('C_1','C_2','C_3','C_4','C_5','C_6','C_7')
        AND location_type BETWEEN 1 AND 6   -- See mapping of type
        AND stock_state IN (1, 2)           -- See mapping of state
    ORDER BY
        snapshot_imported_at DESC -- There is one snapshot per day at hours 23:00. Order to select the latest.
),

-- CTE: Prepare prices and types of culinary skus
culinary_sku_data AS (
    SELECT
        sp.hellofresh_week,
        cs.code AS sku_code,
        cs.name as sku_name,
        sp.price as unit_cost,
        product_types,
        DENSE_RANK () OVER (PARTITION BY sp.culinary_sku_id ORDER BY sp.hellofresh_week DESC) as rn
    FROM materialized_views.procurement_services_staticprices sp -- STATIC PRICES
    JOIN materialized_views.procurement_services_culinarysku cs -- CULINARY SKUS
        ON sp.culinary_sku_id = cs.id
    WHERE
        cs.market = 'dach'
        AND sp.hellofresh_year >= 2023
        AND sp.distribution_center IN ('VE', 'FI', 'BV')
        AND sp.price > 0
),

-- CTE: Load prices and types
sku_data AS (
    SELECT
        sku_code,
        sku_name,
        product_types,
        round(AVG(unit_cost),4) AS unit_cost
    FROM culinary_sku_data
    WHERE rn = 1
    GROUP BY 1,2,3
),

-- calculate current week
current_week_cte AS (
    SELECT hellofresh_running_week AS current_week
    FROM dimensions.date_dimension
    WHERE date_string_backwards = current_date
), 

-- CTE: Load calendar and categorise windows: 0 = past, 1 = current 6 weeks, 2 = 7-12 weeks, 3 = 13-24 weeks, 4 = future
hf_calendar AS (
    SELECT
        date_string_backwards,
        day_name,
        hellofresh_week,
        hellofresh_running_week,
        CASE
            WHEN hellofresh_running_week BETWEEN cw.current_week AND cw.current_week + 5 THEN 1
            WHEN hellofresh_running_week < cw.current_week THEN 0
            WHEN hellofresh_running_week BETWEEN cw.current_week + 6 AND cw.current_week + 11 THEN 2
            WHEN hellofresh_running_week BETWEEN cw.current_week + 12 AND cw.current_week + 23 THEN 3
            ELSE 4
        END AS hf_week_out
    FROM
        dimensions.date_dimension dd,
        current_week_cte cw
    WHERE
        date_string_backwards >= '2024%'
),

-- CTE: Prepare temperature class data
temp_class_data AS (
    SELECT DISTINCT
        prod_code,
        temperature_class,
        event_time,
        DENSE_RANK() OVER (PARTITION BY prod_code ORDER BY event_time DESC) AS row_number
    FROM fcms_mis.mi_prod
    WHERE dc IN ('fi', 'pi') 
        AND LEFT(prod_code, 3) IN ('C_1','C_2','C_3','C_4','C_5','C_6','C_7')
    ORDER BY event_time DESC
),

-- CTE: Load temperature class
temp_class AS (
    SELECT 
        prod_code,
        temperature_class
    FROM temp_class_data 
    WHERE row_number = 1
),

----------------- end Prep INVENTORY source

-------------------------------------------------- INVENTORY source
inventory_source AS (
    SELECT 
        ls.sku_code,
        sd.sku_name,
        ls.dc_code,
        ls.transport_module_id as tm_id__po_id,
        ls.lot_code,
        ls.location_id,
        CASE 
            WHEN ls.expiration_time::DATE <= '2030-12-31' THEN ls.expiration_time::DATE
            WHEN ls.expiration_time::DATE IS NULL THEN '2030-12-31'
            ELSE '2030-12-31'
        END AS expiration_date,
        ls.quantity,
        LEFT(ls.sku_code, 3) AS category,
        COALESCE(sd.unit_cost,0) AS unit_cost,
        CASE 
            WHEN ls.discardment_date::DATE <= '2030-12-31' THEN ls.discardment_date::DATE
            WHEN ls.discardment_date::DATE IS NULL THEN '2030-12-31'
            ELSE '2030-12-31'
        END AS discardment_date,
        (TO_DATE(ls.snapshot_imported_at, 'yyyyMMdd') + INTERVAL '1 day')::DATE AS opening_stock__arr_date, -- Opening stock of the next day.
        ls.snapshot_time,
        sd.product_types,
        cal.hellofresh_week,
        CASE
            WHEN cal.hf_week_out IS NULL THEN 4
            ELSE cal.hf_week_out
        END AS hf_week_out, 
        tc.temperature_class,
        'in' AS data_source,
        '' AS logical_mlor,
        '' AS supplier_code,
        '' AS ssku_mlor,
        '' AS mlor_source
    FROM latest_snapshot ls -- inventory snapshot
    LEFT JOIN sku_data sd ON ls.sku_code = sd.sku_code -- prices and types 
    LEFT JOIN hf_calendar cal ON ls.discardment_date = cal.date_string_backwards -- calendar
    LEFT JOIN temp_class tc ON ls.sku_code = tc.prod_code -- temperature class
    WHERE 1=1
        AND ((ls.dc_code = 'FI' AND ls.row_number = 1) -- Last night's
        OR (ls.dc_code = 'PI' AND ls.row_number_ve = 1)) -- Last Friday (after Cleardown)
    ORDER BY 3,1,7,4
),

-------------------------------------------------- end INVENTORY source


----------------- Prep PO source

-- CTE: selects the Effective Date and filters the PO source
effective_po_data as(
    SELECT 
    *,
    CASE
        WHEN dc_bob_code = 'FI' THEN CURRENT_DATE
        WHEN dc_bob_code = 'PI' THEN 
        CASE 
            WHEN EXTRACT(DOW FROM CURRENT_DATE) = 7 THEN CURRENT_DATE
            ELSE CURRENT_DATE - INTERVAL '1 day' * (EXTRACT(DOW FROM CURRENT_DATE) )
        END
    END AS effective_date
    FROM materialized_views.int_scm_analytics_ot_consolidated_view
    WHERE dc_bob_code in ('FI', 'PI')
        AND expected_arrival_date >= '2024-06-01'
        AND LEFT(sku, 3) IN ('C_1','C_2','C_3','C_4','C_5','C_6','C_7')
),

------------------------------------------------------------------------------------------------------------------------------------ MLOR Section


-- CTE: Selects the SSKU MLOR for the DACH region / Ingredients
mlor_data as (
    SELECT
        ss.supplier_id,
        ss.culinary_sku_code AS sku_code,
        INT(get_json_object(sn.extras, '$.min_shelf_life_on_deliver')) AS ssku_mlor
    FROM materialized_views.procurement_services_suppliersku ss
    LEFT JOIN materialized_views.procurement_services_suppliersku_nutrition sn ON ss.culinary_sku_id = sn.culinary_sku_id AND ss.id = sn.supplier_sku_id
    WHERE ss.status = 'Active'
        AND sn.supplier_sku_status = 'Active'
        AND ss.market = 'dach'
        AND LEFT(ss.culinary_sku_code,3) IN ('C_1','C_2','C_3','C_4','C_5','C_6','C_7')
),

------------------------------------------------------------------------------------------------------------------------------------ MLOR Section
-- CTE: Filters for the effective data only and pulls MLOR, (et al.)
enriched_po_data as(
    SELECT 
        LEAST(expected_arrival_date::DATE,TO_DATE('2030-12-31', 'yyyy-MM-dd')) AS opening_stock__arr_date,
        expected_arrival_date::DATE,
        supplier_name, 
        supplier_code, -- 113184, 112988
        company_id,
        sku AS sku_code, 
        left(sku,3) as category,
        item_quantity as quantity,
        sd.sku_name,
        complete_order_number, 
        dc_bob_code AS dc_code,
        COALESCE(sd.unit_cost,0) AS unit_cost, 
        -- LOGICAL MLOR
        -- Outer Case = use first the SSKU MLOR, and if not available, use the fixed value proposed by Jule
        -- Inner Case = depending on the category, put a minimum of 7 or 8 days
        CASE 
            -- If you have a good ssku mlor, use it (for C_5 use at least 8)
            WHEN md.ssku_mlor IS NOT NULL AND md.ssku_mlor >= 7 THEN 
                CASE 
                    WHEN LEFT(sku, 3) = 'C_5' THEN GREATEST(md.ssku_mlor, 8) 
                    ELSE md.ssku_mlor -- since it's already >= 7 
                END 
            -- If you do not have a good mlor and you must use a fixed minimum value by category
            ELSE 
                CASE 
                    WHEN LEFT(sku, 3) = 'C_1' THEN 84
                    WHEN LEFT(sku, 3) = 'C_2' THEN 21
                    WHEN LEFT(sku, 3) = 'C_3' THEN 37
                    WHEN LEFT(sku, 3) = 'C_4' THEN 360
                    WHEN LEFT(sku, 3) = 'C_5' THEN 8
                    WHEN LEFT(sku, 3) = 'C_6' THEN 270
                    WHEN LEFT(sku, 3) = 'C_7' THEN 10
                    WHEN LEFT(sku, 3) = 'C_8' THEN 365
                    ELSE 7 
                END 
        END AS logical_mlor,
        -- MLOR Source
        CASE
            WHEN md.ssku_mlor IS NOT NULL THEN 'SSKU_MLOR'
            ELSE 'fixed_value_MLOR'
        END AS mlor_source, 
        md.ssku_mlor, --this is the sps SSKU MLOR
        --am.fallback_mlor,
        sd.product_types,
        tc.temperature_class
    FROM effective_po_data po
    LEFT JOIN materialized_views.procurement_services_facility fa ON supplier_code = facility_code
    LEFT JOIN mlor_data md ON company_id = md.supplier_id AND sku = md.sku_code
    --LEFT JOIN avg_sku_mlor am ON po.sku = am.sku_code
    LEFT JOIN sku_data sd ON po.sku = sd.sku_code -- prices and types
    LEFT JOIN temp_class tc ON po.sku = tc.prod_code -- temperature class
    WHERE 1=1
        AND expected_arrival_date >= effective_date
        AND fa.market = 'dach' -- important! there are same codes for different market
),

-- CTE: calculates Expiration Date and Discardment Date to make it "Inventory-ready"
dated_po_data as(
    SELECT
        *,
        CASE -- Expiration Date = Arrival Date + Logical MLOR. If the Expiration date lies beyond 2030 it gets corrected
            WHEN DATE_ADD(expected_arrival_date, logical_mlor) <= '2030-12-31' THEN DATE_ADD(expected_arrival_date, logical_mlor)
            ELSE '2030-12-31'
        END AS expiration_date, -- arrival date + mlor
        CASE WHEN DATE_ADD(expected_arrival_date, logical_mlor) <= '2030-12-31' THEN
            CASE  -- Discardment date calculated based on category: C_5 = 0 ACL, C_7 and other categories = 5 ACL.
                WHEN LEFT(sku_code, 3) = 'C_5' THEN DATE_ADD(expected_arrival_date, logical_mlor)
                ELSE (DATE_ADD(expected_arrival_date, logical_mlor) - INTERVAL '4 days')
            END 
        ELSE '2030-12-31'
        END AS discardment_date
    FROM enriched_po_data
),

-- CTE: exclude these values from the POs based on Dc-SKU-Supplier combinations
exclusion_list as (
    SELECT 'dc' AS dc_code, 'sku-code' AS sku_code, 12345 AS supplier_code
),

----------------- end Prep PO source

-------------------------------------------------- PO source
po_source AS (
    SELECT
        sku_code,
        sku_name,
        dc_code,
        complete_order_number as tm_id__po_id, 
        '' AS lot_code, -- empty
        '' AS location_id, -- empty
        expiration_date,
        quantity,
        category,
        unit_cost, 
        discardment_date,
        opening_stock__arr_date,
        '' AS snapshot_time, -- TS empty for POs
        product_types,
        cal.hellofresh_week,
        CASE
            WHEN cal.hf_week_out IS NULL THEN 4
            ELSE cal.hf_week_out
        END AS hf_week_out,
        temperature_class,
        'po' AS data_source,
        logical_mlor,
        supplier_code,
        ssku_mlor,
        mlor_source
    FROM dated_po_data dpd
    LEFT JOIN hf_calendar cal ON dpd.discardment_date = cal.date_string_backwards -- calendar
    WHERE NOT EXISTS (
        SELECT 1
        FROM exclusion_list el
        WHERE dpd.dc_code = el.dc_code AND dpd.sku_code = el.sku_code AND dpd.supplier_code = el.supplier_code)
)

SELECT * FROM inventory_source
UNION ALL 
SELECT * FROM po_source;