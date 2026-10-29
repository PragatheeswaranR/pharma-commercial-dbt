select
    terr_id                    as territory_id,
    product_code               as product_id,
    quarter_start_dt           as quarter_start_date,
    quota_trx,
    _loaded_at                 as loaded_at
from {{ source('pharma_raw', 'quotas') }}
