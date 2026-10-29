/*
  MICROBATCH INCREMENTAL MODEL (dbt 1.9+)
  dbt splits the work into time batches (one per month here) using event_time.
  Each batch is filtered automatically — no is_incremental() block needed —
  because stg_calls declares event_time: call_date.
  Rerun a past window:
    dbt run --select fct_calls --event-time-start "2026-01-01" --event-time-end "2026-03-01"
*/
{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'microbatch',
        event_time           = 'call_date',
        batch_size           = 'month',
        begin                = '2024-10-01',
        lookback             = 1,
        tags                 = ['calls', 'weekly']
    )
}}

select
    call_id,
    rep_id,
    hcp_id,
    product_id,
    call_date,
    date_trunc('week', call_date)::date     as call_week,
    {{ fiscal_quarter('call_date') }}       as fiscal_quarter,
    call_channel,
    call_channel ilike 'in-person%'         as is_face_to_face,
    samples_dropped,
    loaded_at
from {{ ref('stg_calls') }}
where call_status = 'Submitted'
