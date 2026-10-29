# Pharma Commercial Analytics — a hands-on dbt project on Snowflake

You'll build the data pipeline a pharma commercial analytics team actually runs: messy vendor
HCP and Rx feeds → clean staging → point-in-time territory crediting → **quota attainment
and incentive-compensation (IC) payouts**, plus brand market share and call activity.

All data is fake, generated in your Snowflake account by `setup/01_setup_and_generate_data.sql`
for a fictional company, **Helix Pharma** (5 own brands vs 5 competitors, 5,000 HCPs, 20 reps,
104 weeks of Rx, ~45k calls, quarterly quotas).

Every major dbt feature is used somewhere in this project, and the guide below walks through
them in order over **two 9-hour days**.

---

## The pipeline

```
RAW (sources)                STAGING (views)          INTERMEDIATE               MARTS
─────────────                ───────────────          ────────────               ─────
hcps ──────────────────────▶ stg_hcps ──┬──▶ hcps_snapshot (SCD2) ─▶ int_hcp_alignment_history ─┐
rx_weekly ─────────────────▶ stg_rx_weekly ─────────────────────────▶ fct_rx_weekly (incremental)─┤
calls ─────────────────────▶ stg_calls ──┬──────────────────────────▶ fct_calls (microbatch)      │
products ──────────────────▶ stg_products│──────────────────────────▶ dim_products               │
territories ───────────────▶ stg_territories ─┐                                                   ▼
reps ──────────────────────▶ stg_reps ────────┴─────────────────────▶ dim_reps        int_rx_credited (ephemeral)
quotas ────────────────────▶ stg_quotas ──────────────────────────────────────────────▶ fct_quota_attainment
                                          └──▶ int_hcp_call_activity ─▶ dim_hcps v1/v2 (contract)   │
SEEDS: specialty_codes, ic_product_weights, ic_payout_curve ─────────────────────────▶ fct_ic_payouts
                                                                agg_brand_market_share (dynamic table)
                                                                hcp_engagement_scores (Python)
```

## What's where

| Path | What it teaches |
|---|---|
| `setup/` | SQL to create the role, warehouse, database and fake data; a script that simulates a new week arriving |
| `dbt_project.yml` | folder-level configs, vars, hooks, grants, query tags, persist_docs |
| `profiles.yml` | connection + dev/prod targets |
| `models/staging/` | sources, freshness, renaming, cleaning, dedupe, generic tests |
| `models/intermediate/` | ephemeral models, point-in-time joins on snapshot history |
| `models/marts/core/` | dimensions, **model contracts**, **model versions** |
| `models/marts/commercial/` | **incremental merge**, **microbatch**, IC logic, **unit tests** |
| `models/marts/realtime/` | Snowflake **dynamic table** |
| `models/marts/ml/` | **Python model** on Snowpark |
| `models/marts/exposures.yml` | exposures |
| `models/docs.md` | doc blocks |
| `snapshots/` | SCD Type 2 snapshot |
| `seeds/` | reference CSVs |
| `macros/` | Jinja macros, custom schema naming, hook macros |
| `tests/` | singular tests + custom generic tests |
| `analyses/` | compiled-but-not-built SQL |
| `selectors.yml` | named selections for scheduling |
| `deploy/` | deploying and scheduling dbt inside Snowflake with Tasks |
| `extras/` | packages (`dbt_utils`), package tests, semantic view |

---

## Before you start (15 min)

1. **Snowflake account.** A trial works for everything except Module 16 (`dbt deps` needs an
   External Access Integration, which trials don't allow).
2. **Get the project into a Workspace** (Snowsight → Projects → Workspaces). Pick one:
   - **Git (recommended — you get version control and a portfolio repo):** push this folder to a
     public GitHub repo, then in a worksheet run:
     ```sql
     use role accountadmin;
     create or replace api integration git_api_integration
       api_provider = git_https_api
       api_allowed_prefixes = ('https://github.com/<your-github-user>')
       allowed_authentication_secrets = all
       enabled = true;
     ```
     Then Workspaces → *Create Workspace from Git repository* → paste the repo URL → pick
     `git_api_integration` → Public repository.
   - **Upload:** create a new workspace and upload the folder's files, keeping the same structure.
3. In the Workspace, open the dbt toolbar: you'll see **project**, **target** (dev/prod) and
   **command** dropdowns, a ▶ button, and an arrow to type extra arguments
   (e.g. `--select stg_hcps`). That's how you run every `dbt ...` command in this guide.

> Running locally instead (VS Code + dbt Core)? See the appendix at the bottom.

---

# DAY 1 — Foundations (≈ 9 hours)

## Module 0 · Generate the data (45 min)

1. Open `setup/01_setup_and_generate_data.sql` in a worksheet and run the whole script.
2. Switch your role to `DBT_ROLE` and explore:
   ```sql
   select * from pharma_dbt.raw.hcps limit 50;          -- spot the messy names and lowercase codes
   select hcp_npi, count(*) from pharma_dbt.raw.hcps group by 1 having count(*) > 1;   -- duplicates
   select * from pharma_dbt.raw.rx_weekly where hcp_npi = '1000001777' order by week_end_dt;
   select * from pharma_dbt.raw.quotas order by quarter_start_dt, terr_id limit 30;
   ```
3. **Write down** three data-quality problems you see. Staging will fix them.

## Module 1 · Project anatomy (45 min)

Read, in this order: `dbt_project.yml` → `profiles.yml` → `macros/generate_schema_name.sql`.

Key ideas:
- A **model** is a `select` statement in a `.sql` file. dbt wraps it in `create view/table as`.
- `ref()` and `source()` build the **DAG** — dbt works out run order from them.
- Configs cascade: `dbt_project.yml` folder config → model's YAML → model's `config()` block (most specific wins).
- **Targets**: `dev` builds into `DEV_STAGING`, `DEV_CORE`…; `prod` builds into `STAGING`, `CORE`…
  That's the custom `generate_schema_name` macro at work.

**Do:** run `dbt debug`, then `dbt parse`. Open the **DAG** view in the Workspace.

## Module 2 · Sources & freshness (1 h)

Read `models/staging/_sources.yml`.

**Do:**
1. Run `dbt source freshness`. All pass — data was just loaded.
2. In a worksheet, age one feed:
   `update pharma_dbt.raw.calls set _loaded_at = dateadd(day, -3, _loaded_at);`
   Rerun freshness → **WARN** on calls. Set it to `-8` days → **ERROR**.
   Fix it back with `set _loaded_at = current_timestamp()`.
3. Notice `rx_weekly` has looser thresholds than the default. **Why does a weekly feed need that?**

## Module 3 · Staging models (1.5 h)

Read every `stg_*.sql`. Pattern: `source` CTE → (dedupe) → rename/cast/clean → `select`.

**Do:**
1. `dbt run --select staging` (or `--select tag:staging`).
2. Look at `stg_hcps`: names fixed, specialty codes uppercase, one row per HCP.
3. Use **Compile** on `stg_hcps` and read the compiled SQL — the `clean_name` macro and the
   `source()` are now real SQL.
4. **Exercise:** add a `stg_hcps` column `is_email_missing` (boolean). Rerun just that model:
   `dbt run --select stg_hcps`.
5. **Selection syntax drill** — predict, then run with `dbt ls`:
   `stg_hcps+` · `+fct_ic_payouts` · `1+dim_hcps` · `tag:staging` · `path:models/marts/core`

## Module 4 · Seeds (30 min)

Read `seeds/*.csv` and `seeds/_seeds.yml` (and the `seeds:` block in `dbt_project.yml` that fixes column types).

**Do:** `dbt seed`. Query `DEV_REFERENCE.IC_PAYOUT_CURVE`.
Seeds are for **small, slowly changing reference data you own** — not for loading real data.

## Module 5 · Tests (1.5 h)

1. **Generic tests** — `unique`, `not_null`, `accepted_values`, `relationships` in `_stg_models.yml`.
2. **Custom generic tests** — `tests/generic/*.sql`: `not_negative`, `value_between` (with arguments), `valid_npi`.
3. **Singular tests** — `tests/assert_*.sql`: any SQL that returns failing rows.
4. **Severity** — the `email` test is `warn` (a known gap shouldn't block the pipeline).

**Do:**
1. `dbt test --select staging`. Note the email **WARN**.
2. **Break it on purpose:**
   `update pharma_dbt.raw.hcps set specialty_cd = 'DERM' where hcp_npi = '1000001777';`
   Rebuild and test stg_hcps (`dbt build --select stg_hcps`) → the `relationships` test fails.
   Look at the failing SQL in the test's compiled output and run it. Revert the update.
3. **Exercise:** write a custom generic test `is_future_date` and apply it to `stg_calls.call_date` with `severity: warn`.
4. Learn `dbt build` = seed + run + snapshot + test, **in DAG order**. A failing test stops its downstream models.

## Module 6 · Documentation (45 min)

Read `models/docs.md` (doc blocks) and how `_stg_models.yml` uses `{{ doc('trx') }}`.

**Do:**
1. `dbt docs generate`. In Snowflake Workspaces, use the **DAG** and model details to browse
   lineage. Because of `persist_docs` in `dbt_project.yml`, descriptions also land as
   Snowflake comments — check with `show views in schema pharma_dbt.dev_staging;`.
2. **Exercise:** add a doc block for `call_channel` and use it in two places.

## Module 7 · Jinja, macros & vars (1.5 h)

Read every file in `macros/`.

- `surrogate_key` loops over a list with `{% for %}` / `loop.last`.
- `safe_divide`, `fiscal_quarter`, `clean_name` — one definition, used everywhere.
- `generate_schema_name` **overrides** a built-in dbt macro.
- `var('target_decile_min')` in `dim_hcps_v2`, `var('ic_payout_cap')` in `fct_ic_payouts`.

**Do:**
1. Compile `fct_rx_weekly` and find the expanded `md5(concat_ws(...))`.
2. Override a var at run time:
   `dbt run --select dim_hcps --vars '{"target_decile_min": 9}'` → count `is_target` HCPs before and after.
3. **Exercise:** write a macro `cents_to_dollars(col)` or `weeks_between(start, end)` and use it.
4. **Exercise:** write a macro `limit_in_dev(n)` that adds `limit n` only when `target.name == 'dev'`.

## Module 8 · Materializations & the intermediate layer (1 h)

| Materialization | Where | What Snowflake gets |
|---|---|---|
| view | staging, intermediate | a view (always fresh, no storage) |
| table | most marts | a table rebuilt each run |
| ephemeral | `int_rx_credited` | **nothing** — inlined as a CTE |
| incremental | `fct_rx_weekly`, `fct_calls` | a table updated in place (Day 2) |
| dynamic_table | `agg_brand_market_share` | a Snowflake dynamic table (Day 2) |

**Do:**
1. `dbt build` — the whole project, first time. Expect a few minutes.
2. Compile `fct_quota_attainment` and find the inlined `int_rx_credited` CTE.
3. Confirm no `INT_RX_CREDITED` object exists in Snowflake.

### Day 1 checkpoint — answer out loud
- `ref` vs `source`? Why never hardcode table names?
- What does `dbt build` do that `dbt run` doesn't?
- When would you pick ephemeral over view?
- How do dev and prod schemas stay separate here?
- Generic vs singular test? How does a custom generic test receive `model` and `column_name`?

---

# DAY 2 — Production patterns (≈ 9 hours)

## Module 9 · Incremental models — merge (1.5 h)

Read `fct_rx_weekly.sql` closely: `is_incremental()`, `{{ this }}`, `unique_key`, `on_schema_change`, `cluster_by`.

**Do:**
1. Note row count and max week: `select count(*), max(week_ending_date) from pharma_dbt.dev_commercial.fct_rx_weekly;`
2. Run `setup/02_simulate_new_week.sql` in a worksheet.
3. `dbt run --select fct_rx_weekly`. Open the query history: you'll see a **MERGE**, not a CREATE.
4. Check: new week inserted, **and** the restated week 3-weeks-back updated (merge on `rx_key`).
5. `dbt run --select fct_rx_weekly --full-refresh` — compare runtime.
6. **Exercise:** add a column `trx_change_vs_prior_week`. What does `append_new_columns` do on the next
   incremental run? Why do old rows have null? (Answer: only new/updated rows get the value — this is why `--full-refresh` exists.)
7. **Think:** what breaks if late data arrives with an *older* `_loaded_at`? How would a lookback window fix it?

## Module 10 · Microbatch (1 h)

Read `fct_calls.sql` and the `event_time` config on `stg_calls`.

**Do:**
1. `dbt run --select fct_calls --full-refresh` — watch the logs: one batch per month.
2. After the new-week simulation, `dbt run --select fct_calls` — only the latest batch (+1 lookback) runs.
3. Backfill a window:
   `dbt run --select fct_calls --event-time-start "2025-06-01" --event-time-end "2025-09-01"`
4. **Compare:** merge (Module 9) vs microbatch. When does each fit? (Hint: event-time data with
   well-defined periods → microbatch; keyed updates/restatements → merge.)

## Module 11 · Snapshots & point-in-time crediting (1.5 h) — *the IC heart of the project*

Read `snapshots/hcps_snapshot.yml` → `int_hcp_alignment_history.sql` → `int_rx_credited.sql`.

**Do:**
1. Look at `pharma_dbt.dev_snapshots.hcps_snapshot` — note `dbt_valid_from` / `dbt_valid_to`.
2. The simulation script realigned ~50 HCPs. Run `dbt snapshot`, then:
   ```sql
   select * from pharma_dbt.dev_snapshots.hcps_snapshot
   where hcp_id in (select hcp_id from pharma_dbt.dev_snapshots.hcps_snapshot group by 1 having count(*) > 1)
   order by hcp_id, dbt_valid_from;
   ```
   Each realigned HCP has a closed old row and an open new row.
3. `dbt build --select +fct_quota_attainment`. Past weeks stay credited to the **old** territory,
   new weeks go to the **new** one. That's correct IC crediting.
4. **Exercise:** switch the snapshot to `strategy: timestamp` with `updated_at: loaded_at`. What changes?
5. **Think:** why snapshot `stg_hcps` instead of the raw source? (Hint: duplicates in raw break `unique_key`.)

## Module 12 · IC marts + unit tests (1.5 h)

Read `fct_quota_attainment.sql` → `fct_ic_payouts.sql` → the `unit_tests:` in `_commercial_models.yml`.

**Do:**
1. `dbt build --select +fct_ic_payouts`. Query payouts — who's above plan, who's at 0?
2. Run only unit tests: `dbt test --select "fct_ic_payouts,test_type:unit"`.
3. **Break the logic:** in `fct_ic_payouts.sql` change `<  c.max_attainment` to `<= c.max_attainment`.
   Rerun the unit tests. They still pass, because no test case sits exactly on a band boundary,
   where `<=` would match two bands and duplicate the payout. Revert the change.
4. **Exercise:** close that gap. Add a unit test for a rep at exactly 0.85 attainment, then
   repeat step 3 and watch it fail.
5. **Exercise (stretch, very real-world):** replace the step curve with **linear interpolation**
   between bands, then update the unit tests' expected values.

## Module 13 · Contracts & model versions (1 h)

Read `_core_models.yml` and both `dim_hcps_v1.sql` / `dim_hcps_v2.sql`.

**Do:**
1. Note both `DIM_HCPS_V1` and `DIM_HCPS_V2` exist in `DEV_CORE`.
2. **Break the contract:** in `dim_hcps_v2.sql` change `decile::number(2,0)` to `decile::varchar`.
   Run it — dbt refuses **before** building. Revert.
3. **Break it differently:** remove `is_target` from the SQL → contract error (missing column).
4. `ref('dim_hcps')` → v2. Pin a consumer with `ref('dim_hcps', v=1)`.
5. **Exercise:** add `latest_version` aliasing so v2 is also published as plain `DIM_HCPS`
   (look up the `alias` config per version).

## Module 14 · Snowflake-specific features (1 h)

- **Dynamic table** — `agg_brand_market_share.sql`. After the build:
  `show dynamic tables in schema pharma_dbt.dev_realtime;` Snowflake refreshes it, not dbt.
  Run the new-week simulation + `dbt run --select fct_rx_weekly`, then
  `alter dynamic table pharma_dbt.dev_realtime.agg_brand_market_share refresh;`
- **Query tags** — every dbt query is tagged `dbt_pharma_commercial` (see `deploy/` for the query).
- **Clustering** — `cluster_by` on `fct_rx_weekly`.
- **Grants** — marts grant SELECT to `IC_REPORTER`. Test it:
  `use role ic_reporter; select * from pharma_dbt.dev_commercial.fct_ic_payouts limit 5;`
  then try `dev_staging` → denied (no grants there).
- **Hooks** — `on-run-start` creates `AUDIT.DBT_RUN_LOG`, `on-run-end` grants schema usage and logs every node.
  `select * from pharma_dbt.audit.dbt_run_log order by logged_at desc;`
- **Exercise:** add `+transient: true` to staging/intermediate tables, or a `post_hook` on
  `fct_ic_payouts` that inserts a row count into the audit schema.

## Module 15 · Python model (30 min)

Read `models/marts/ml/hcp_engagement_scores.py`.

**Do:** `dbt run --select hcp_engagement_scores --vars '{"enable_python_models": true}'`.
Query the tiers. Notice the aggregation happens in Snowpark first; only small data goes to pandas.
> If your environment rejects Python models, read the code and run it later from a local dbt setup.

## Module 16 · Packages, dbt_utils & semantic views (45 min)

*Needs a non-trial account.*

1. Run `setup/03_external_access_for_packages.sql`.
2. Copy `extras/packages.yml` to the project root. Run **deps** with the external access
   integration `DBT_ACCESS_INTEGRATION` (dropdown arrow → enter it).
3. Copy `extras/_dbt_utils_tests.yml` into `models/marts/commercial/` → `dbt test`.
4. Replace the hand-written `surrogate_key` with `dbt_utils.generate_surrogate_key` in one model. Same output?
5. Copy `extras/sv_commercial_performance.sql` into `models/marts/realtime/` and run it — a semantic view
   you can point Cortex Analyst at.

## Module 17 · Selectors, tags, exposures, analyses (45 min)

**Do:**
1. `dbt ls --selector ic_close` · `dbt ls --selector weekly_refresh`
2. `dbt ls --select +exposure:ic_quarterly_payout_report` — everything the IC report depends on.
3. Compile `analyses/call_reach_and_frequency.sql`, copy the compiled SQL into a worksheet, run it.
4. **Exercise:** add a selector `brand_only` = `tag:brand` plus its parents.

## Module 18 · Deploy & orchestrate in Snowflake (1 h)

Follow `deploy/deploy_and_schedule.sql`:
1. Deploy the Workspace project as a **DBT PROJECT** object in `PHARMA_DBT.OPS`.
2. `execute dbt project ... args = 'seed --target prod'`, then a prod build.
   Prod schemas have no prefix: `STAGING`, `CORE`, `COMMERCIAL`.
3. Create the task graph: **freshness → weekly build**, plus a quarterly **IC close** task.
4. Trigger it, watch `task_history`, read your audit log.
5. **Suspend the tasks and the dynamic tables when you're done.**

### Capstone (whatever time is left)
Pick one and build it end to end with tests and docs:
- **Rx-based HCP decile recalculation:** a model that recomputes deciles from the last 52 weeks of TRx, compared with the vendor's decile.
- **Call plan compliance:** planned vs actual calls per rep per quarter, joined to target HCPs.
- **IC dispute support:** for a rep and quarter, list every HCP whose realignment moved TRx in or out.

### Day 2 checkpoint — answer out loud
- Merge vs microbatch vs full table — trade-offs?
- How do you handle late-arriving data in an incremental model?
- Why snapshots for HCP alignment? What breaks if you join Rx to *current* alignment?
- Data test vs unit test?
- What does a model contract protect, and what is a version for?
- How does dbt run in production on Snowflake without dbt Cloud?

---

## Command cheat-sheet

```text
dbt debug | parse | compile | ls
dbt seed                         dbt run --select stg_hcps+
dbt snapshot                     dbt test --select test_type:unit
dbt build                        dbt build --select +fct_ic_payouts
dbt source freshness             dbt run --full-refresh --select fct_rx_weekly
dbt build --selector ic_close    dbt run --vars '{"target_decile_min": 9}'
dbt build --target prod          dbt run --select fct_calls --event-time-start "2025-06-01" --event-time-end "2025-09-01"
```

## Reset everything

```sql
use role dbt_role;
drop schema if exists pharma_dbt.dev_staging;  -- or drop and recreate all DEV_* schemas
-- full reset: rerun setup/01 and `dbt build --full-refresh`
```

---

## Appendix · Running locally with VS Code + dbt Core

```bash
python -m venv .venv && source .venv/bin/activate
pip install dbt-core dbt-snowflake
```

Put this in `~/.dbt/profiles.yml` (instead of the project's `profiles.yml`):

```yaml
pharma_commercial:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <orgname-accountname>
      user: <your_user>
      authenticator: externalbrowser
      role: DBT_ROLE
      warehouse: DBT_WH
      database: PHARMA_DBT
      schema: DEV
      threads: 4
```

Then `dbt debug` and follow the same modules. Locally you also get `dbt docs serve` for the full docs site.
