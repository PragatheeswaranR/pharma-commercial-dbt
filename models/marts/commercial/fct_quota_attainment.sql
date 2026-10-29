-- Territory x own-brand x quarter: actual TRx (credited by point-in-time alignment) vs quota.
{{ config(tags = ['ic']) }}

with credited as (

    select * from {{ ref('int_rx_credited') }}
    where is_own_brand

),

actuals as (

    select
        credited_territory_id                               as territory_id,
        product_id,
        date_trunc('quarter', week_ending_date)::date       as quarter_start_date,
        sum(trx)                                            as actual_trx,
        sum(nrx)                                            as actual_nrx
    from credited
    group by 1, 2, 3

),

quotas as (

    select * from {{ ref('stg_quotas') }}

)

select
    {{ surrogate_key(['q.territory_id', 'q.product_id', 'q.quarter_start_date']) }}  as attainment_key,
    q.territory_id,
    q.product_id,
    q.quarter_start_date,
    {{ fiscal_quarter('q.quarter_start_date') }}                                    as fiscal_quarter,
    q.quota_trx,
    coalesce(a.actual_trx, 0)                                                       as actual_trx,
    coalesce(a.actual_nrx, 0)                                                       as actual_nrx,
    round({{ safe_divide('coalesce(a.actual_trx, 0)', 'q.quota_trx') }}, 4)         as attainment_pct
from quotas q
left join actuals a
    on  q.territory_id       = a.territory_id
    and q.product_id         = a.product_id
    and q.quarter_start_date = a.quarter_start_date
