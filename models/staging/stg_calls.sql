with source as (

    select * from {{ source('pharma_raw', 'calls') }}

)

select
    call_id,
    emp_id               as rep_id,
    hcp_npi              as hcp_id,
    call_dt              as call_date,
    call_channel,
    product_detailed     as product_id,
    call_status,
    samples_qty          as samples_dropped,
    _loaded_at           as loaded_at
from source
