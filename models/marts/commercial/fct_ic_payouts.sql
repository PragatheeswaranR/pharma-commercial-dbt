/*
  Quarterly incentive-compensation payout per rep.
    1. weighted attainment = sum(product attainment x product weight)
    2. look up the payout band on the payout curve
    3. payout = min(payout_pct, cap) x quarterly target incentive
*/
{{ config(tags = ['ic']) }}

with attainment as (

    select * from {{ ref('fct_quota_attainment') }}

),

weights as (

    select * from {{ ref('ic_product_weights') }}

),

reps as (

    select * from {{ ref('dim_reps') }}

),

curve as (

    select * from {{ ref('ic_payout_curve') }}

),

weighted as (

    select
        r.rep_id,
        r.rep_name,
        r.region_name,
        a.territory_id,
        a.fiscal_quarter,
        a.quarter_start_date,
        round(sum(a.attainment_pct * w.weight), 4)          as weighted_attainment,
        max(r.annual_target_incentive) / 4                  as quarterly_target_incentive
    from attainment a
    join reps r    on a.territory_id = r.territory_id
    join weights w on a.product_id   = w.product_id
    group by 1, 2, 3, 4, 5, 6

)

select
    {{ surrogate_key(['w.rep_id', 'w.fiscal_quarter']) }}                        as payout_key,
    w.rep_id,
    w.rep_name,
    w.region_name,
    w.territory_id,
    w.fiscal_quarter,
    w.quarter_start_date,
    w.weighted_attainment,
    w.quarterly_target_incentive,
    coalesce(c.payout_pct, 0)                                                   as payout_pct,
    round(least(coalesce(c.payout_pct, 0), {{ var('ic_payout_cap') }})
          * w.quarterly_target_incentive, 2)                                    as payout_amount
from weighted w
left join curve c
    on  w.weighted_attainment >= c.min_attainment
    and w.weighted_attainment <  c.max_attainment
