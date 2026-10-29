-- No rep may be paid more than the cap (ic_payout_cap x quarterly target incentive).
{{ config(severity = 'error', tags = ['ic']) }}

select *
from {{ ref('fct_ic_payouts') }}
where payout_amount > {{ var('ic_payout_cap') }} * quarterly_target_incentive + 0.01
