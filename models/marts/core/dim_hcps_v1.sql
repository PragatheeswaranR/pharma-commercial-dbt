-- VERSION 1 of dim_hcps (deprecated). Kept so downstream users can migrate on their own timeline.
-- Contract is enforced: every column's name and type must match _core_models.yml.
with hcps as (

    select * from {{ ref('stg_hcps') }}

),

specialties as (

    select * from {{ ref('specialty_codes') }}

)

select
    hcps.hcp_id::varchar                                        as hcp_id,
    (hcps.first_name || ' ' || hcps.last_name)::varchar         as full_name,
    hcps.specialty_code::varchar                                as specialty_code,
    s.specialty_name::varchar                                   as specialty_name,
    hcps.state_code::varchar                                    as state_code,
    hcps.territory_id::varchar                                  as territory_id,
    hcps.decile::number(2,0)                                    as decile
from hcps
left join specialties s
    on hcps.specialty_code = s.specialty_code
