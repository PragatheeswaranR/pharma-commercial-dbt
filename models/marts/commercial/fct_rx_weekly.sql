/*
  INCREMENTAL MODEL (merge strategy)
  First run  : builds the full table from all of stg_rx_weekly.
  Later runs : is_incremental() is true, so only rows loaded since the last run
               are selected, then MERGEd on rx_key:
                 - existing key  -> UPDATE (late-arriving restatements)
                 - new key       -> INSERT (new weeks)
  Force a full rebuild with:  dbt build --select fct_rx_weekly --full-refresh
*/
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'merge',
        unique_key           = 'rx_key',
        on_schema_change     = 'append_new_columns',
        cluster_by           = ['week_ending_date'],
        tags                 = ['rx', 'weekly']
    )
}}

with rx as (

    select * from {{ ref('stg_rx_weekly') }}

    {% if is_incremental() %}
    -- {{ this }} = this model's own table in Snowflake
    where loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ltz) from {{ this }})
    {% endif %}

)

select
    {{ surrogate_key(['hcp_id', 'product_id', 'week_ending_date']) }}   as rx_key,
    hcp_id,
    product_id,
    week_ending_date,
    {{ fiscal_quarter('week_ending_date') }}                            as fiscal_quarter,
    trx,
    nrx,
    trx - nrx                                                           as refills,
    data_vendor,
    loaded_at
from rx
