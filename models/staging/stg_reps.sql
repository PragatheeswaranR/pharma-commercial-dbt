select
    emp_id                     as rep_id,
    rep_full_name              as rep_name,
    terr_id                    as territory_id,
    title,
    hire_dt                    as hire_date,
    annual_target_incentive,
    email,
    _loaded_at                 as loaded_at
from {{ source('pharma_raw', 'reps') }}
