-- Every quota row must map to a rep, or someone's payout silently disappears.
select q.*
from {{ ref('fct_quota_attainment') }} q
left join {{ ref('dim_reps') }} r on q.territory_id = r.territory_id
where r.rep_id is null
