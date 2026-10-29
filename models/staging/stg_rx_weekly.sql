with source as (

    select * from {{ source('pharma_raw', 'rx_weekly') }}

)

select
    hcp_npi          as hcp_id,
    product_code     as product_id,
    week_end_dt      as week_ending_date,
    nrx_cnt          as nrx,
    trx_cnt          as trx,
    data_vendor,
    _loaded_at       as loaded_at
from source
