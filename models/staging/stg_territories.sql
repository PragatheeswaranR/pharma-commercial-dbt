select
    terr_id          as territory_id,
    terr_name        as territory_name,
    region_name,
    region_manager,
    _loaded_at       as loaded_at
from {{ source('pharma_raw', 'territories') }}
