
--this cte provides basic calendar data
WITH cal as (
    SELECT distinct 
        hellofresh_week
        , hellofresh_month
        , hellofresh_quarter
        , hellofresh_year
        , date_string_backwards
    FROM dimensions.date_dimension
    WHERE hellofresh_year>=2024
),

-- this cte gives all the events in fcms of stock deletions with waste related reasons (donation, disposal and resale to processor)
inventory AS (
    SELECT
        UPPER(ST.dc) as DC
        , cal.hellofresh_week as hf_week
        , ST.prod_code as sku_code
        , "inventory_waste" as source
        , CASE
            WHEN st.sla_reason_id = 'DON' THEN 'donation'
            WHEN st.sla_reason_id = 'DIS' THEN 'disposal'
            WHEN st.sla_reason_id = 'RES' THEN 'resale' --we dont have transactions yet, but might have in the future. Let's include it - Duncan
        END as destination
        , LEFT(ST.prod_code, 3) as sku_category
        , cal.date_string_backwards as delivery_date
        , SUM(ST.qty) as waste_units
    FROM fcms_mis.mi_stock ST
    LEFT JOIN cal
        ON left(from_unixtime(CAST(FLOOR(ST.event_time/1000) AS INT)),10) = cal.date_string_backwards
    WHERE ST.oel_class = "OEL_STOCK_DELETE" --"OEL_STOCK_QTY_CHANGE" is included by global query as well but adds only 41 rows as of now and with a lot of data quality issues (e.g. negative quantities from_value-to_value)
        AND ST.dc IN ('FI','PI')
        AND st.qty<10000000 --exclude extreme wrong casesS
        AND UPPER(ST.sla_reason_id) IN ('DIS','DON','RES')
        AND TO_DATE(FROM_UNIXTIME(CAST(FLOOR(ST.event_time/1000) AS INT))) >= TO_DATE('2023-12-30')
        AND LEFT(ST.prod_code,3) NOT IN ('C_20', 'C_21', 'C_22') --- exclude categories that are not relevant to material waste
    GROUP BY 1,2,3,4,5,6,7
),

-- cte to retrieve sku data
sku as (
    SELECT  DISTINCT 
        code
        , name as sku_name
        , packaging_type
        , CASE 
            WHEN packaging_type like 'Meal Kit%' THEN 'YES' 
            ELSE 'NO' 
        END as in_meal_kit
    FROM materialized_views.procurement_services_culinarysku
    WHERE market='dach'
),

-- this cte retrieves the picklist data, which is necessary to reach the sku level with the mk overproduction data
picklist as (
    SELECT distinct 
        picklist.hellofresh_week
        , ucase(region_code) as region
        , picklist.slot_number as recipe_index
        , picklist.code as sku_code
        , picklist.size
        , picklist.pick_count as picks
        , picklist.name as sku_name
    FROM materialized_views.isa_services_menu_picklist AS picklist
    WHERE 1=1
        AND picklist.hellofresh_week >='2024-W01'
        AND picklist.region_code ='deat'
        AND picklist.unique_recipe_code NOT LIKE '%-TM-%' --exclude thermomix rows from picklist
),

-- this cte merges the two data sources of waste into one: waste derived from inventory deletions and mealkit overproduction
total_waste as (
--waste from overproduction
    SELECT
        mk.dc
        ,mk.week as hf_week
        , picklist.sku_code
        ,'overkitting_waste' as source
        ,'donation' as destination  --assumption: all mealkit overproduction goes to donation
        ,left(picklist.sku_code,3) as sku_category
        , MIN(cal.date_string_backwards) as delivery_date -------------------------------------------------------------------------------------------------------------------------------------------------------------
        , SUM( picklist.picks * 
            CASE 
                WHEN picklist.size = 2 then mk_2p
                WHEN picklist.size = 3 then mk_3p
                WHEN picklist.size = 4 then mk_4p
            END
        ) as waste_units
FROM public_dach_oa_gsheets.dach_mk_overproduction mk
LEFT JOIN picklist
    ON mk.slot = picklist.recipe_index
    AND mk.week = picklist.hellofresh_week
left join cal 
    on mk.week = cal.hellofresh_week
WHERE 1=1
GROUP BY 1,2,3,4,5,6

UNION ALL
--waste from inventory deletions

SELECT *
FROM inventory
)

SELECT distinct 
    total.dc
    , 'DE' as country
    , concat(cal.hellofresh_year, '-', lpad(cal.hellofresh_month, 2, '0')) as hf_month
    , total.hf_week
    , to_date(delivery_date, 'dd-MM-yyyy') as delivery_date
    , total.source
    , total.destination
    , total.sku_code as sku
    , total.sku_category
    , sku.sku_name
    , cast(total.waste_units as bigint) as delivery_quantity
FROM total_waste as total
LEFT JOIN sku
    ON sku.code = total.sku_code
LEFT JOIN cal
    ON cal.hellofresh_week = total.hf_week
WHERE 1=1
    AND total.waste_units>0 --some rows have 0 units because of the mk overproduction files, which has all slots even if with 0 units
    AND (CASE 
            WHEN total.source='inventory_waste' THEN true
            WHEN total.source='overkitting_waste' THEN sku.in_meal_kit='YES' 
        END)=TRUE --criteria to only get the skus that are packed in the mealkit if the waste source is mealkit overproduction
;
