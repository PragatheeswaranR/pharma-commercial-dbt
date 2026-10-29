/*
  DYNAMIC TABLE (Snowflake-specific materialization)
  dbt creates it once; after that SNOWFLAKE refreshes it automatically to stay
  within target_lag of its sources — no dbt run needed for fresh data.
  dbt only re-creates it when the SQL/config changes.
*/
{{
    config(
        materialized        = 'dynamic_table',
        target_lag          = '1 day',
        snowflake_warehouse = 'DBT_WH',
        tags                = ['brand']
    )
}}

with rx as (

    select * from {{ ref('fct_rx_weekly') }}

),

products as (

    select * from {{ ref('dim_products') }}

),

weekly as (

    select
        rx.week_ending_date,
        p.therapeutic_area,
        p.brand_name,
        p.is_own_brand,
        sum(rx.trx)  as trx,
        sum(rx.nrx)  as nrx
    from rx
    join products p on rx.product_id = p.product_id
    group by 1, 2, 3, 4

)

select
    week_ending_date,
    therapeutic_area,
    brand_name,
    is_own_brand,
    trx,
    nrx,
    round(trx / nullif(sum(trx) over (partition by week_ending_date, therapeutic_area), 0), 4) as trx_market_share,
    round(nrx / nullif(sum(nrx) over (partition by week_ending_date, therapeutic_area), 0), 4) as nrx_market_share
from weekly
