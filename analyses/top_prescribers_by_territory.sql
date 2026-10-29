-- ANALYSIS: compiled by dbt (refs resolved) but never built.
-- Compile it, copy the SQL from target/compiled/..., and run it as an ad-hoc query.
with ranked as (
    select
        h.territory_id,
        h.hcp_id,
        h.full_name,
        h.specialty_name,
        h.decile,
        sum(rx.trx) as trx_last_13_weeks,
        row_number() over (partition by h.territory_id order by sum(rx.trx) desc) as rnk
    from {{ ref('fct_rx_weekly') }} rx
    join {{ ref('dim_hcps') }} h on rx.hcp_id = h.hcp_id
    join {{ ref('dim_products') }} p on rx.product_id = p.product_id and p.is_own_brand
    where rx.week_ending_date >= dateadd(week, -13, current_date())
    group by 1, 2, 3, 4, 5
)
select * from ranked where rnk <= 10 order by territory_id, rnk
