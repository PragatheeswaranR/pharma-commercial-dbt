/*
  Point-in-time HCP -> territory alignment, built from the snapshot.
  Each row says: "from valid_from until valid_to, this HCP belonged to this territory."

  Gotcha: the snapshot only starts recording on its FIRST run, so the first version
  of every HCP gets dbt_valid_from = "today". We stretch the first version back to
  1900-01-01 so historical Rx weeks still find a territory.
*/
with snap as (

    select * from {{ ref('hcps_snapshot') }}

)

select
    hcp_id,
    territory_id,
    case
        when row_number() over (partition by hcp_id order by dbt_valid_from) = 1
            then '1900-01-01'::timestamp_ntz
        else dbt_valid_from::timestamp_ntz
    end                                                         as valid_from,
    coalesce(dbt_valid_to, '9999-12-31')::timestamp_ntz         as valid_to,
    dbt_valid_to is null
        or dbt_valid_to::date = '9999-12-31'::date              as is_current
from snap
