/* =====================================================================
   PHARMA COMMERCIAL dbt LEARNING PROJECT — 01: SETUP + DUMMY DATA
   Run this whole script once in a Snowsight SQL worksheet.
   Creates: role, warehouse, database, RAW schema, and ~1.5M rows of
   realistic (fake) pharma commercial data for "Helix Pharma".
   Runtime on an X-Small warehouse: ~1-2 minutes.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1. Roles, warehouse, database
-- ---------------------------------------------------------------------
use role accountadmin;

create role if not exists dbt_role;       -- dbt builds everything as this role
create role if not exists ic_reporter;    -- read-only consumers (IC team / BI) - used to learn dbt grants
grant role dbt_role to role sysadmin;

set my_user = current_user();
grant role dbt_role    to user identifier($my_user);
grant role ic_reporter to user identifier($my_user);

create warehouse if not exists dbt_wh
  warehouse_size = xsmall
  auto_suspend = 60
  auto_resume = true
  initially_suspended = true;
grant usage, operate on warehouse dbt_wh to role dbt_role;
grant usage on warehouse dbt_wh to role ic_reporter;

create database if not exists pharma_dbt;
grant ownership on database pharma_dbt to role dbt_role copy current grants;
grant usage on database pharma_dbt to role ic_reporter;

-- needed later (Module 18) to schedule dbt with Snowflake Tasks
grant execute task on account to role dbt_role;

use role dbt_role;
use warehouse dbt_wh;
use database pharma_dbt;
create schema if not exists raw;
use schema raw;

-- ---------------------------------------------------------------------
-- 2. PRODUCTS  (5 own brands from Helix Pharma + 5 competitors)
-- ---------------------------------------------------------------------
create or replace table products (
  product_code      varchar,
  brand_name        varchar,
  generic_name      varchar,
  therapeutic_area  varchar,
  manufacturer      varchar,
  launch_date       date,
  wac_per_unit      number(12,2),
  _loaded_at        timestamp_ltz default current_timestamp()
);

insert into products (product_code, brand_name, generic_name, therapeutic_area, manufacturer, launch_date, wac_per_unit) values
  ('P001','Cardiovex' ,'vexartan'   ,'Cardiovascular','Helix Pharma','2019-03-01',  412.50),
  ('P002','Arteris'   ,'lorasartan' ,'Cardiovascular','Novagen Labs','2015-06-15',  298.00),
  ('P003','Glycara'   ,'glucafozin' ,'Diabetes'      ,'Helix Pharma','2021-01-10',  575.00),
  ('P004','Insulyn XR','metravide'  ,'Diabetes'      ,'Meridian Bio','2017-09-01',  489.90),
  ('P005','Oncotrix'  ,'trexolimab' ,'Oncology'      ,'Helix Pharma','2022-05-20',12850.00),
  ('P006','Tumavex'   ,'zelcotinib' ,'Oncology'      ,'Novagen Labs','2018-11-30',11200.00),
  ('P007','Respira'   ,'fluvapro'   ,'Respiratory'   ,'Helix Pharma','2020-08-01',  345.00),
  ('P008','Breathon'  ,'salmidrol'  ,'Respiratory'   ,'Meridian Bio','2016-02-14',  310.00),
  ('P009','Neurolin'  ,'cerazepine' ,'Neuroscience'  ,'Helix Pharma','2023-02-01',  890.00),
  ('P010','Synaptra'  ,'valdoxetine','Neuroscience'  ,'Novagen Labs','2014-07-07',  720.00);

-- ---------------------------------------------------------------------
-- 3. TERRITORIES (20 territories in 4 regions)
-- ---------------------------------------------------------------------
create or replace table territories (
  terr_id         varchar,
  terr_name       varchar,
  region_name     varchar,
  region_manager  varchar,
  _loaded_at      timestamp_ltz default current_timestamp()
);

insert into territories (terr_id, terr_name, region_name, region_manager) values
  ('T01','Boston North'   ,'Northeast','Priya Raman'),
  ('T02','Boston South'   ,'Northeast','Priya Raman'),
  ('T03','New York Metro' ,'Northeast','Priya Raman'),
  ('T04','Philadelphia'   ,'Northeast','Priya Raman'),
  ('T05','Pittsburgh'     ,'Northeast','Priya Raman'),
  ('T06','Atlanta'        ,'Southeast','Marcus Bell'),
  ('T07','Miami'          ,'Southeast','Marcus Bell'),
  ('T08','Charlotte'      ,'Southeast','Marcus Bell'),
  ('T09','Nashville'      ,'Southeast','Marcus Bell'),
  ('T10','Tampa'          ,'Southeast','Marcus Bell'),
  ('T11','Chicago North'  ,'Central'  ,'Elena Ortiz'),
  ('T12','Chicago South'  ,'Central'  ,'Elena Ortiz'),
  ('T13','Dallas'         ,'Central'  ,'Elena Ortiz'),
  ('T14','Houston'        ,'Central'  ,'Elena Ortiz'),
  ('T15','Minneapolis'    ,'Central'  ,'Elena Ortiz'),
  ('T16','Los Angeles'    ,'West'     ,'Kenji Watanabe'),
  ('T17','San Francisco'  ,'West'     ,'Kenji Watanabe'),
  ('T18','Seattle'        ,'West'     ,'Kenji Watanabe'),
  ('T19','Denver'         ,'West'     ,'Kenji Watanabe'),
  ('T20','Phoenix'        ,'West'     ,'Kenji Watanabe');

-- ---------------------------------------------------------------------
-- 4. REPS (one sales rep per territory)
-- ---------------------------------------------------------------------
create or replace table reps as
with g as (
  select row_number() over (order by seq4()) as n
  from table(generator(rowcount => 20))
),
named as (
  select n,
    get(array_construct('Anita Sharma','Brian Cole','Chloe Park','David Mensah','Emma Lowe',
                        'Farhan Qureshi','Grace Liu','Hector Ruiz','Isha Patel','Jason Reed',
                        'Kavya Nair','Liam Foster','Maya Brooks','Nikhil Rao','Olivia Grant',
                        'Pedro Alves','Quinn Harper','Rhea Kapoor','Samuel Ortiz','Tara Singh'), n - 1)::varchar as full_name
  from g
)
select
  'E' || lpad(n::varchar, 4, '0')                                   as emp_id,
  full_name                                                         as rep_full_name,
  'T' || lpad(n::varchar, 2, '0')                                   as terr_id,
  case when mod(n, 5) = 0 then 'Senior Sales Specialist' else 'Sales Specialist' end as title,
  dateadd(day, -uniform(200, 3000, random()), current_date())       as hire_dt,
  case when mod(n, 5) = 0 then 50000 else 40000 end::number(12,2)   as annual_target_incentive,
  lower(replace(full_name, ' ', '.')) || '@helixpharma.example'     as email,
  current_timestamp()                                               as _loaded_at
from named;

-- ---------------------------------------------------------------------
-- 5. HCPs (5,000 prescribers) — deliberately MESSY, like real vendor data:
--    inconsistent name casing, stray spaces, lowercase specialty codes,
--    missing emails, and 100 duplicate (older) records to dedupe.
-- ---------------------------------------------------------------------
create or replace table hcps as
with g as (
  select row_number() over (order by seq4()) as n
  from table(generator(rowcount => 5000))
),
base as (
  select n,
    get(array_construct('James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda','David','Elizabeth',
                        'Arjun','Sneha','Wei','Mei','Carlos','Lucia','Ahmed','Fatima','Kenji','Yuki',
                        'Daniel','Sarah','Matthew','Karen','Ravi','Pooja','Ethan','Nora','Omar','Leila'),
        uniform(0, 29, random()))::varchar as fn,
    get(array_construct('Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
                        'Iyer','Menon','Chen','Wang','Lopez','Gonzalez','Khan','Hassan','Tanaka','Sato',
                        'Wilson','Anderson','Thomas','Taylor','Reddy','Gupta','Moore','Clark','Lewis','Walker'),
        uniform(0, 29, random()))::varchar as ln,
    get(array_construct('CARD','CARD','ENDO','ENDO','ONC','PULM','NEUR','IM','IM','IM','FM','FM'),
        uniform(0, 11, random()))::varchar as spec,
    'T' || lpad(uniform(1, 20, random())::varchar, 2, '0') as terr,
    get(array_construct('MA','NY','PA','GA','FL','NC','TN','IL','TX','MN','CA','WA','CO','AZ'),
        uniform(0, 13, random()))::varchar as st,
    uniform(1, 10, random()) as decile
  from g
)
select
  (1000000000 + n * 1777)::varchar                                    as hcp_npi,
  case when mod(n, 9) = 0  then upper(fn)
       when mod(n, 13) = 0 then '  ' || lower(fn) || ' '
       else fn end                                                    as first_nm,
  case when mod(n, 11) = 0 then upper(ln) else ln end                 as last_nm,
  case when mod(n, 17) = 0 then lower(spec) else spec end             as specialty_cd,
  terr                                                                as terr_id,
  st                                                                  as state_cd,
  decile                                                              as decile_rank,
  case when mod(n, 10) = 0 then null
       else lower(fn) || '.' || lower(ln) || n || '@clinic.example' end as email_addr,
  dateadd(minute, -uniform(1, 600, random()), current_timestamp())    as _loaded_at
from base;

-- 100 duplicate records with an OLDER load timestamp and a stale decile (staging must keep the latest)
insert into hcps
select hcp_npi, first_nm, last_nm, specialty_cd, terr_id, state_cd,
       greatest(1, decile_rank - 2), email_addr,
       dateadd(day, -3, _loaded_at)
from hcps sample (100 rows);

-- ---------------------------------------------------------------------
-- 6. RX_WEEKLY — 104 weeks of TRx/NRx per HCP x product (~1.4M rows)
--    HCPs only prescribe products in their therapeutic areas.
--    Own brands trend up over time; competitors drift down slightly.
-- ---------------------------------------------------------------------
create or replace table rx_weekly as
with weeks as (
  select row_number() over (order by seq4()) - 1 as wk_back
  from table(generator(rowcount => 104))
),
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
pairs as (
  select h.hcp_npi, h.decile_rank, p.product_code,
         (p.manufacturer = 'Helix Pharma') as is_own,
         case when p.therapeutic_area = 'Oncology' then 0.3 else 1.0 end as vol_factor
  from hcp h
  join spec_ta s  on h.spec = s.spec
  join products p on p.therapeutic_area = s.ta
),
gen as (
  select
    pr.hcp_npi,
    pr.product_code,
    dateadd(week, -w.wk_back, previous_day(current_date(), 'friday')) as week_end_dt,
    greatest(0, round(
      pr.decile_rank * pr.vol_factor * uniform(0.4::float, 1.6::float, random())
      * case when pr.is_own then 1 + (103 - w.wk_back) * 0.004
             else 1 - (103 - w.wk_back) * 0.001 end
    ))::number(10,0) as trx_cnt
  from pairs pr
  cross join weeks w
)
select
  hcp_npi,
  product_code,
  week_end_dt,
  round(trx_cnt * uniform(0.15::float, 0.45::float, random()))::number(10,0) as nrx_cnt,
  trx_cnt,
  'XPO_WEEKLY'          as data_vendor,
  current_timestamp()   as _loaded_at
from gen;

-- ---------------------------------------------------------------------
-- 7. CALLS — rep visits to HCPs (~45k). Higher-decile HCPs get called more.
-- ---------------------------------------------------------------------
create or replace table calls as
with h as (
  select hcp_npi, terr_id, upper(trim(specialty_cd)) as spec, decile_rank
  from hcps
  qualify row_number() over (partition by hcp_npi order by _loaded_at desc) = 1
),
primary_ta as (
  select column1 as spec, column2 as ta from values
    ('CARD','Cardiovascular'), ('ENDO','Diabetes'), ('ONC','Oncology'), ('PULM','Respiratory'),
    ('NEUR','Neuroscience'), ('IM','Cardiovascular'), ('FM','Diabetes')
),
g as (
  select h.*, uniform(1, 10, random()) as roll,
         dateadd(day, -uniform(0, 720, random()), current_date()) as call_dt,
         get(array_construct('In-Person Detail','In-Person Detail','In-Person Detail','Virtual Detail','Lunch & Learn'),
             uniform(0, 4, random()))::varchar as call_channel,
         uniform(1, 100, random()) as status_roll,
         uniform(0, 6, random())   as samples_qty
  from h
  cross join table(generator(rowcount => 16))
)
select
  'C' || lpad(row_number() over (order by g.call_dt, g.hcp_npi)::varchar, 7, '0') as call_id,
  r.emp_id,
  g.hcp_npi,
  g.call_dt,
  g.call_channel,
  p.product_code                     as product_detailed,
  case when g.status_roll <= 4 then 'Cancelled' else 'Submitted' end as call_status,
  g.samples_qty,
  current_timestamp()                as _loaded_at
from g
join reps r        on r.terr_id = g.terr_id
join primary_ta pt on pt.spec = g.spec
join products p    on p.therapeutic_area = pt.ta and p.manufacturer = 'Helix Pharma'
where g.roll <= g.decile_rank;

-- ---------------------------------------------------------------------
-- 8. QUOTAS — quarterly TRx quota per territory x own brand
--    (actuals x random 0.92–1.12 so reps land in different payout bands)
-- ---------------------------------------------------------------------
create or replace table quotas as
with hcp as (
  select hcp_npi, terr_id
  from hcps
  qualify row_number() over (partition by hcp_npi order by _loaded_at desc) = 1
),
actuals as (
  select h.terr_id, r.product_code,
         date_trunc('quarter', r.week_end_dt)::date as quarter_start_dt,
         sum(r.trx_cnt) as actual_trx
  from rx_weekly r
  join hcp h      on h.hcp_npi = r.hcp_npi
  join products p on p.product_code = r.product_code and p.manufacturer = 'Helix Pharma'
  group by 1, 2, 3
)
select
  terr_id,
  product_code,
  quarter_start_dt,
  round(actual_trx * uniform(0.92::float, 1.12::float, random()))::number(12,0) as quota_trx,
  current_timestamp() as _loaded_at
from actuals;

-- ---------------------------------------------------------------------
-- 9. Sanity check
-- ---------------------------------------------------------------------
select 'products' as tbl, count(*) as row_count from products union all
select 'territories', count(*) from territories union all
select 'reps',        count(*) from reps        union all
select 'hcps',        count(*) from hcps        union all
select 'rx_weekly',   count(*) from rx_weekly   union all
select 'calls',       count(*) from calls       union all
select 'quotas',      count(*) from quotas
order by 1;
