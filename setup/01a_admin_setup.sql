/* =====================================================================
   01a: ADMIN SETUP  — run FIRST, once.
   Workspace context selector:  Role = ACCOUNTADMIN
   (Workspaces use the context selector at the top of the editor; USE ROLE
    lines inside a file may not carry over between statements, so set it there.)
   Creates: DBT_ROLE, IC_REPORTER, DBT_WH warehouse, PHARMA_DBT database,
            RAW schema, a credit cap, and the Git integration for GitHub.
   Safe to re-run.
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

create schema if not exists pharma_dbt.raw;
grant ownership on schema pharma_dbt.raw to role dbt_role copy current grants;

-- ---------------------------------------------------------------------
-- 2. Credit safety net: hard-stop DBT_WH at 20 credits
-- ---------------------------------------------------------------------
create or replace resource monitor dbt_learning_cap
  with credit_quota = 20
  frequency = never
  start_timestamp = immediately
  triggers
    on 50 percent do notify
    on 80 percent do notify
    on 100 percent do suspend_immediate;
alter warehouse dbt_wh set resource_monitor = dbt_learning_cap;

-- ---------------------------------------------------------------------
-- 3. Git integration so a Workspace can be created from your GitHub repo
--    (change the URL if your GitHub username differs)
-- ---------------------------------------------------------------------
create or replace api integration git_api_integration
  api_provider = git_https_api
  api_allowed_prefixes = ('https://github.com/PragatheeswaranR')
  allowed_authentication_secrets = all
  enabled = true;
grant usage on integration git_api_integration to role dbt_role;

-- ---------------------------------------------------------------------
-- 4. Check
-- ---------------------------------------------------------------------
show roles like 'DBT_ROLE';
show databases like 'PHARMA_DBT';
show integrations like 'GIT_API_INTEGRATION';
