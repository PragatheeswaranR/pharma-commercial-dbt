-- Call activity per HCP — reach and frequency inputs for dim_hcps.
with calls as (

    select * from {{ ref('stg_calls') }}
    where call_status = 'Submitted'

)

select
    hcp_id,
    count(*)                                                        as lifetime_calls,
    count_if(call_date >= dateadd(day, -90, current_date()))        as calls_last_90d,
    max(call_date)                                                  as last_call_date,
    sum(samples_dropped)                                            as lifetime_samples
from calls
group by hcp_id
