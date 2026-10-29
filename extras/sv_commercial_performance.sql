-- MODULE 16 — after `dbt deps`, copy into models/marts/realtime/ and run `dbt run --select sv_commercial_performance`.
-- Builds a Snowflake SEMANTIC VIEW: business metrics defined once, queryable by
-- BI tools and Cortex Analyst ("what was Cardiovex TRx share last quarter?").
{{ config(materialized = 'semantic_view') }}

TABLES (
  rx       AS {{ ref('fct_rx_weekly') }} PRIMARY KEY (rx_key),
  products AS {{ ref('dim_products') }}  PRIMARY KEY (product_id),
  hcps     AS {{ ref('dim_hcps') }}      PRIMARY KEY (hcp_id)
)
RELATIONSHIPS (
  rx_to_product AS rx(product_id) REFERENCES products(product_id),
  rx_to_hcp     AS rx(hcp_id)     REFERENCES hcps(hcp_id)
)
FACTS (
  rx.trx_units AS trx,
  rx.nrx_units AS nrx
)
DIMENSIONS (
  rx.week_ending_date      AS week_ending_date,
  rx.fiscal_quarter        AS fiscal_quarter,
  products.brand_name      AS brand_name,
  products.therapeutic_area AS therapeutic_area,
  products.is_own_brand    AS is_own_brand,
  hcps.hcp_segment         AS hcp_segment,
  hcps.territory_id        AS territory_id
)
METRICS (
  rx.total_trx AS SUM(rx.trx_units),
  rx.total_nrx AS SUM(rx.nrx_units)
)
