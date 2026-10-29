select
    product_id,
    brand_name,
    generic_name,
    therapeutic_area,
    manufacturer,
    is_own_brand,
    launch_date,
    datediff(month, launch_date, current_date())    as months_since_launch,
    wac_per_unit
from {{ ref('stg_products') }}
