WITH 
cal as (
SELECT 
    hellofresh_year
    , date_string_backwards
    , hellofresh_week
    , hellofresh_month
FROM dimensions.date_dimension
where hellofresh_year >= 2024
    and date_string_backwards <= current_date),

picklist AS (
    SELECT DISTINCT 
        picklist.hellofresh_week
        , picklist.slot_number AS recipe_index
        , picklist.code AS sku_code
        , picklist.size
        , picklist.pick_count AS picks
        , picklist.name AS sku_name
    FROM materialized_views.isa_services_menu_picklist AS picklist
    WHERE 1=1
        AND picklist.hellofresh_week >= '2024-W01'
        AND picklist.region_code = 'deat'
        AND picklist.unique_recipe_code NOT LIKE '%-TM-%' -- exclude thermomix rows from picklist
),

boxes AS (
    SELECT
        distribution_center as dc
        , hf_week
        , to_date(delivery_date) as delivery_date
        , country
        , meal_selection
        , marketing_skus
        , ice_data
        , box_data
        , pouch_data
        , mealkit_size
        , boxid
        , concat(cal.hellofresh_year, '-', lpad(cal.hellofresh_month, 2, '0')) as hf_month
        , from_json(box_data, 'struct<box_sku:STRING,box_size:STRING,box_weight:FLOAT>') AS json_boxes          -- box data, pouch_data and ice_data are structure
        , from_json(pouch_data, 'struct<cool_pouch_sku:STRING,cool_pouch_weight:FLOAT,cool_pouch_name:STRING>') AS json_pouch 
        , from_json(ice_data, 'struct<ice_pack_sku:STRING,number_ice_packs:INT,total_ice_count:INT,ice_in_contact:INT,ice_pack_weight:FLOAT>') as json_ice
    FROM dach_tech.or_store_boxes
    join cal 
        on to_date(delivery_date) = cal.date_string_backwards  -- join calendar on day
    WHERE 1=1
        AND workspace = 'main_workspace'
        AND user_name = 'or-client'
        AND run_name = 'or-client-run'
        AND input_type = 'actuals'
        AND shipped = 'true'
        and distribution_center in ('PI', 'FI')
        and hf_week >= '2024-W01' -- from PDL only 2024 and onwards

),

exploded_data AS (
    -- Step 1: Explode `meal_selection` JSON array and join it with the `picklist` CTE
    SELECT
        hf_month
        , hf_week 
        , delivery_date
        , dc
        , country
        , boxid
        , 'meal_selection' AS source
        , picklist.sku_code AS sku   -- SKU from the picklist
        , picklist.picks AS quantity  -- Picks from the picklist
    FROM boxes
    CROSS JOIN LATERAL explode(from_json(boxes.meal_selection, 'array<struct<meal_type:STRING,menu_slot:INT,quantity:INT,bag_size:INT>>')) AS json_meal(col)    -- meal data is stored as an array and must be parsed into a struct
    LEFT JOIN picklist
        ON col.menu_slot = picklist.recipe_index
        AND col.bag_size = picklist.size
        AND boxes.hf_week = picklist.hellofresh_week   


     -- Step 2: Explode `marketing_skus` JSON array
    union all
    SELECT
        hf_month
        , hf_week
        , delivery_date
        , dc
        , country
        , boxid
        , 'marketing_skus' AS source
        , json_marketing.col.sku_code AS sku
        , json_marketing.col.quantity AS quantity
    FROM boxes
    CROSS JOIN LATERAL explode(from_json(boxes.marketing_skus, 'array<struct<short_name:STRING,sku_code:STRING,quantity:INT,item_type:STRING,item_container:STRING>>')) as json_marketing(col)    -- meal data is stored as an array and must be parsed into a struct


    -- Step 3: Parse `ice_data` JSON directly in the SELECT clause
    union all
    SELECT
        hf_month
        , hf_week
        , delivery_date
        , dc
        , country
        , boxid
        , 'ice_data' AS source
        , json_ice.ice_pack_sku AS sku
        , json_ice.number_ice_packs AS quantity
    FROM boxes


    -- Step 4: Parse `box_data` JSON directly in the SELECT clause
    union all
    SELECT 
        hf_month
        , hf_week
        , delivery_date
        , dc
        , country
        , boxid
        , 'box_data' AS source
        , json_boxes.box_sku AS sku
        , 1 as quantity
    FROM boxes


    -- Step 5: Parse `pouch_data` JSON directly in the SELECT clause
    union all    
    SELECT 
        hf_month
        , hf_week
        , delivery_date
        , dc
        , country
        , boxid
        , 'pouch_data' as source
        , json_pouch.cool_pouch_sku as sku
        , 1 as quantity
    FROM boxes

    -- Step 6: Parse `mealkit_bag_data` STRING
    union all 
    select 
        hf_month
        , hf_week
        , delivery_date
        , dc
        , country
        , boxid
        , 'mk_bag_data' as source
        , case
            when mk_size = 'S' then 'alias-71755' 
            when mk_size = 'L' then 'alias-78743' 
            else 'alias-14342' /* Medium and Z / others are mapped to M */ 
          end as sku
        , 1 as quantity
    from (
            SELECT 
                explode(split(mealkit_size, '-')) AS mk_size -- explode the string like (M-M-S) as individual rows
                , * 
            FROM boxes)

),

procurement_names as (
    SELECT distinct
        code as sku
        , name as sku_name
    FROM materialized_views.procurement_services_culinarysku
    where market = 'dach'
)


SELECT 
    dc
    , country
    , hf_month
    , hf_week
    , delivery_date
    , source
    , 'paying_customer' as destination
    --, boxid
    , ed.sku
    , left(ed.sku,3) as sku_category
    , sku_name
    , sum(quantity) as delivery_quantity
FROM exploded_data ed
left join procurement_names on ed.sku = procurement_names.sku
where 1=1 
    and quantity > 0 -- there are a few 0 quantity (two per months) for ice data with skus: alias-30557 and null
    and ed.sku is not null 
group by 1,2,3,4,5,6,7,8,9,10
;