-- Singular test: a one-off SQL check. Returns rows that break the rule.
-- New prescriptions are a subset of total prescriptions, so NRx can never exceed TRx.
select *
from {{ ref('fct_rx_weekly') }}
where nrx > trx
