/* =====================================================================
   03: EXTERNAL ACCESS INTEGRATION (only for Module 16 — dbt packages)
   `dbt deps` must download packages from hub.getdbt.com / GitHub.
   Snowflake blocks outbound network by default, so we allow those hosts.
   NOTE: External Access Integrations are NOT available on trial accounts.
   On a trial account, skip Module 16's hands-on part (read it instead).
   ===================================================================== */
use role accountadmin;

create or replace network rule pharma_dbt.raw.dbt_network_rule
  mode = egress
  type = host_port
  value_list = ('hub.getdbt.com', 'codeload.github.com');

create or replace external access integration dbt_access_integration
  allowed_network_rules = (pharma_dbt.raw.dbt_network_rule)
  enabled = true;

grant usage on integration dbt_access_integration to role dbt_role;
