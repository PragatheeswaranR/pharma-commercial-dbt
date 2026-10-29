/* =====================================================================
   MODULE 18 — DEPLOY + ORCHESTRATE dbt INSIDE SNOWFLAKE
   Step 1: Deploy the project from the Workspace:
           Workspace toolbar → "Connect" → "Deploy dbt project"
           Database: PHARMA_DBT · Schema: OPS · Name: PHARMA_COMMERCIAL
     (CLI alternative:  snow dbt deploy pharma_commercial --source . --database pharma_dbt --schema ops)
   Step 2: Run the statements below in a SQL worksheet.
   ===================================================================== */
use role dbt_role;
use warehouse dbt_wh;
create schema if not exists pharma_dbt.ops;

-- See what got deployed
show dbt projects in schema pharma_dbt.ops;

-- Run it on demand (same args you'd type after "dbt")
execute dbt project pharma_dbt.ops.pharma_commercial args = 'seed --target prod';
execute dbt project pharma_dbt.ops.pharma_commercial args = 'build --target prod --selector weekly_refresh';

-- ---------------------------------------------------------------------
-- Task graph:  freshness check  →  weekly build
-- If freshness ERRORs, the task fails and the build never runs (stale data never reaches IC).
-- ---------------------------------------------------------------------
create or replace task pharma_dbt.ops.t_source_freshness
  warehouse = dbt_wh
  schedule  = 'USING CRON 0 6 * * MON Asia/Kolkata'
as
  execute dbt project pharma_dbt.ops.pharma_commercial args = 'source freshness --target prod';

create or replace task pharma_dbt.ops.t_weekly_build
  warehouse = dbt_wh
  after pharma_dbt.ops.t_source_freshness
as
  execute dbt project pharma_dbt.ops.pharma_commercial args = 'build --target prod --selector weekly_refresh';

-- Quarter-end IC close: 5th day after each quarter ends
create or replace task pharma_dbt.ops.t_ic_close
  warehouse = dbt_wh
  schedule  = 'USING CRON 0 8 5 1,4,7,10 * Asia/Kolkata'
as
  execute dbt project pharma_dbt.ops.pharma_commercial args = 'build --target prod --selector ic_close';

-- Resume children before the root
alter task pharma_dbt.ops.t_weekly_build     resume;
alter task pharma_dbt.ops.t_source_freshness resume;
alter task pharma_dbt.ops.t_ic_close         resume;

-- Trigger the graph now instead of waiting for Monday
execute task pharma_dbt.ops.t_source_freshness;

-- ---------------------------------------------------------------------
-- Monitor
-- ---------------------------------------------------------------------
select name, state, scheduled_time, completed_time, error_message
from table(pharma_dbt.information_schema.task_history())
where database_name = 'PHARMA_DBT'
order by scheduled_time desc
limit 20;

-- Our own audit log, written by the on-run-end hook
select target_name, status, count(*) as nodes, round(sum(execution_seconds), 1) as seconds, max(logged_at) as finished
from pharma_dbt.audit.dbt_run_log
group by 1, 2
order by finished desc;

-- Every query dbt ran is tagged (see +query_tag in dbt_project.yml)
select query_text, total_elapsed_time / 1000 as seconds, start_time
from table(pharma_dbt.information_schema.query_history())
where query_tag = 'dbt_pharma_commercial'
order by start_time desc
limit 20;

-- ---------------------------------------------------------------------
-- When you're done learning: stop the schedules (they cost credits)
-- ---------------------------------------------------------------------
-- alter task pharma_dbt.ops.t_source_freshness suspend;
-- alter task pharma_dbt.ops.t_ic_close suspend;
-- alter dynamic table pharma_dbt.realtime.agg_brand_market_share suspend;
-- alter dynamic table pharma_dbt.dev_realtime.agg_brand_market_share suspend;
