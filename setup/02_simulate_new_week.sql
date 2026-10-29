/* =====================================================================
   02: SIMULATE A NEW WEEK OF DATA ARRIVING
   Run this whenever the guide says "simulate a new week" (Modules 9-11).
   Each run:
     a) loads one new week of Rx data
     b) restates last-3-weeks Rx for some HCPs (late-arriving corrections)
     c) realigns ~50 HCPs to a different territory (new CDC record)
     d) adds ~700 new calls
   Then re-run dbt and watch incremental models, microbatch, snapshots
   and alignment-based crediting react.
   ===================================================================== */
use role dbt_role;
use warehouse dbt_wh;
use schema pharma_dbt.raw;

-- a) New week of Rx -----------------------------------------------------
insert into rx_weekly
with next_week as (select dateadd(week, 1, max(week_end_dt)) as wk from rx_weekly),
spec_ta as (
  select column1 as spec, column2 as ta from values
    ('CARD','Cardiovascular'), ('ENDO','Diabetes'), ('ONC','Oncology'), ('PULM','Respiratory'),
    ('NEUR','Neuroscience'), ('IM','Cardiovascular'), ('IM','Diabetes'), ('FM','Cardiovascular'), ('FM','Diabetes')
),
hcp as (
  select hcp_npi, upper(trim(specialty_cd)) as spec, decile_rank
  from hcps
  qualify row_number() over (partition by hcp_npi order by _loaded_at desc) = 1
),
gen as (
  select h.hcp_npi, p.product_code, nw.wk as week_end_dt,
         greatest(0, round(h.decile_rank
              * case when p.therapeutic_area = 'Oncology' then 0.3 else 1.0 end
              * uniform(0.4::float, 1.6::float, random())
              * case when p.manufacturer = 'Helix Pharma' then 1.45 else 0.9 end))::number(10,0) as trx_cnt
  from hcp h
  join spec_ta s  on h.spec = s.spec
  join products p on p.therapeutic_area = s.ta
  cross join next_week nw
)
select hcp_npi, product_code, week_end_dt,
       round(trx_cnt * uniform(0.15::float, 0.45::float, random()))::number(10,0),
       trx_cnt, 'XPO_WEEKLY', current_timestamp()
from gen;

-- b) Late-arriving restatement for a week that was already loaded ---------
update rx_weekly
set trx_cnt    = trx_cnt + 2,
    nrx_cnt    = nrx_cnt + 1,
    _loaded_at = current_timestamp()
where week_end_dt = (select dateadd(week, -3, max(week_end_dt)) from rx_weekly)
  and mod(hcp_npi::number, 25) = 0;

-- c) Territory realignment: append a NEW version of ~50 HCP records ---------
insert into hcps
select hcp_npi, first_nm, last_nm, specialty_cd,
       'T' || lpad(uniform(1, 20, random())::varchar, 2, '0') as terr_id,
       state_cd, decile_rank, email_addr,
       current_timestamp()
from hcps
where mod(hcp_npi::number, 97) = 0
qualify row_number() over (partition by hcp_npi order by _loaded_at desc) = 1;

-- d) New calls this week -------------------------------------------------
insert into calls
with h as (
  select hcp_npi, terr_id, upper(trim(specialty_cd)) as spec
  from hcps
  where decile_rank >= 6
  qualify row_number() over (partition by hcp_npi order by _loaded_at desc) = 1
),
primary_ta as (
  select column1 as spec, column2 as ta from values
    ('CARD','Cardiovascular'), ('ENDO','Diabetes'), ('ONC','Oncology'), ('PULM','Respiratory'),
    ('NEUR','Neuroscience'), ('IM','Cardiovascular'), ('FM','Diabetes')
),
mx as (select max(to_number(substr(call_id, 2))) as max_id from calls),
picked as (select * from h order by random() limit 700)
select
  'C' || lpad((mx.max_id + row_number() over (order by p.hcp_npi))::varchar, 7, '0'),
  r.emp_id, p.hcp_npi,
  dateadd(day, -uniform(0, 6, random()), current_date()),
  'In-Person Detail',
  pr.product_code,
  'Submitted',
  uniform(0, 6, random()),
  current_timestamp()
from picked p
cross join mx
join reps r        on r.terr_id = p.terr_id
join primary_ta pt on pt.spec = p.spec
join products pr   on pr.therapeutic_area = pt.ta and pr.manufacturer = 'Helix Pharma';

select 'latest rx week' as what, max(week_end_dt)::varchar as value from rx_weekly
union all select 'hcp versions', count(*)::varchar from hcps
union all select 'calls', count(*)::varchar from calls;
