-- VERSION 2 of dim_hcps (latest).
-- BREAKING change vs v1: specialty_code removed.
-- New: therapeutic area, segment, target flag, call activity.
with hcps as (

    select * from {{ ref('stg_hcps') }}

),

specialties as (

    select * from {{ ref('specialty_codes') }}

),

activity as (

    select * from {{ ref('int_hcp_call_activity') }}

)

select
    hcps.hcp_id::varchar                                        as hcp_id,
    (hcps.first_name || ' ' || hcps.last_name)::varchar         as full_name,
    s.specialty_name::varchar                                   as specialty_name,
    s.primary_therapeutic_area::varchar                         as primary_therapeutic_area,
    hcps.state_code::varchar                                    as state_code,
    hcps.territory_id::varchar                                  as territory_id,
    hcps.decile::number(2,0)                                    as decile,
    (case
        when hcps.decile >= 8 then 'High'
        when hcps.decile >= 5 then 'Medium'
        else 'Low'
     end)::varchar                                              as hcp_segment,
    (hcps.decile >= {{ var('target_decile_min') }})::boolean    as is_target,
    coalesce(a.calls_last_90d, 0)::number(10,0)                 as calls_last_90d,
    a.last_call_date::date                                      as last_call_date
from hcps
left join specialties s
    on hcps.specialty_code = s.specialty_code
left join activity a
    on hcps.hcp_id = a.hcp_id
