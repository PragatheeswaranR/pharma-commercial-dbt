with source as (

    select * from {{ source('pharma_raw', 'products') }}

)

select
    product_code                                         as product_id,
    brand_name,
    generic_name,
    therapeutic_area,
    manufacturer,
    manufacturer = '{{ var("own_manufacturer") }}'       as is_own_brand,
    launch_date,
    wac_per_unit,
    _loaded_at                                           as loaded_at
from source
