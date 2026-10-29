with reps as (

    select * from {{ ref('stg_reps') }}

),

territories as (

    select * from {{ ref('stg_territories') }}

)

select
    reps.rep_id,
    reps.rep_name,
    reps.email,
    reps.title,
    reps.hire_date,
    datediff(year, reps.hire_date, current_date())   as tenure_years,
    reps.annual_target_incentive,
    reps.territory_id,
    t.territory_name,
    t.region_name,
    t.region_manager
from reps
left join territories t
    on reps.territory_id = t.territory_id
