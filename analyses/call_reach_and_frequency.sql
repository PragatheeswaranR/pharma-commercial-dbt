-- Reach = % of target HCPs called at least once in the quarter.
-- Frequency = average calls per reached target HCP.
with target_hcps as (
    select hcp_id, territory_id from {{ ref('dim_hcps') }} where is_target
),
quarter_calls as (
    select hcp_id, count(*) as calls
    from {{ ref('fct_calls') }}
    where call_date >= date_trunc('quarter', current_date())
    group by 1
)
select
    t.territory_id,
    count(*)                                              as target_hcps,
    count(c.hcp_id)                                       as reached_hcps,
    round(count(c.hcp_id) / count(*), 3)                  as reach_pct,
    round(avg(c.calls), 2)                                as avg_frequency
from target_hcps t
left join quarter_calls c on t.hcp_id = c.hcp_id
group by 1
order by reach_pct desc
