"""
PYTHON MODEL (runs on Snowpark inside Snowflake).
Disabled by default — enable with var enable_python_models: true (Module 15).

Scores each HCP on engagement = blend of call volume and prescribing volume,
then buckets HCPs into 4 tiers. Heavy aggregation is pushed down to Snowflake
with Snowpark; only the small per-HCP result is pulled into pandas.
"""
import pandas as pd
import snowflake.snowpark.functions as F


def model(dbt, session):
    dbt.config(materialized="table", packages=["pandas"])

    calls = (
        dbt.ref("fct_calls")
        .group_by("HCP_ID")
        .agg(F.count("CALL_ID").alias("TOTAL_CALLS"))
    )
    rx = (
        dbt.ref("fct_rx_weekly")
        .group_by("HCP_ID")
        .agg(F.sum("TRX").alias("TOTAL_TRX"))
    )
    hcps = dbt.ref("dim_hcps").select("HCP_ID", "DECILE", "TERRITORY_ID")

    df = (
        hcps.join(rx, on="HCP_ID", how="left")
            .join(calls, on="HCP_ID", how="left")
            .to_pandas()
    )
    df[["TOTAL_TRX", "TOTAL_CALLS"]] = df[["TOTAL_TRX", "TOTAL_CALLS"]].fillna(0)

    # percentile ranks -> weighted score -> quartile tier
    df["TRX_PCTL"] = df["TOTAL_TRX"].rank(pct=True)
    df["CALL_PCTL"] = df["TOTAL_CALLS"].rank(pct=True)
    df["ENGAGEMENT_SCORE"] = (0.6 * df["TRX_PCTL"] + 0.4 * df["CALL_PCTL"]).round(4)
    df["ENGAGEMENT_TIER"] = pd.qcut(
        df["ENGAGEMENT_SCORE"].rank(method="first"),
        4,
        labels=["Tier 4 - Low", "Tier 3", "Tier 2", "Tier 1 - High"],
    ).astype(str)

    return df[["HCP_ID", "TERRITORY_ID", "DECILE", "TOTAL_TRX", "TOTAL_CALLS",
               "ENGAGEMENT_SCORE", "ENGAGEMENT_TIER"]]
