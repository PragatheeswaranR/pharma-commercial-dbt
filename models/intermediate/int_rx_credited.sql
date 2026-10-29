/*
  Credits every Rx row to the territory the HCP was aligned to IN THAT WEEK.
  This is the core of IC crediting: realignments must not rewrite history.

  Materialized as EPHEMERAL: dbt inlines this SQL as a CTE wherever it is ref()'d.
  Nothing is created in Snowflake for this model.
*/
{{ config(materialized = 'ephemeral') }}

with rx as (

    select * from {{ ref('fct_rx_weekly') }}

),

alignment as (

    select * from {{ ref('int_hcp_alignment_history') }}

),

products as (

    select product_id, is_own_brand from {{ ref('dim_products') }}

)

select
    rx.rx_key,
    rx.hcp_id,
    rx.product_id,
    p.is_own_brand,
    rx.week_ending_date,
    a.territory_id         as credited_territory_id,
    rx.trx,
    rx.nrx
from rx
join products p
    on rx.product_id = p.product_id
join alignment a
    on  rx.hcp_id = a.hcp_id
    and rx.week_ending_date::timestamp_ntz >= a.valid_from
    and rx.week_ending_date::timestamp_ntz <  a.valid_to
