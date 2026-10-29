{#
  Overrides dbt's built-in schema naming.
  Default dbt behaviour:  <target schema>_<custom schema>   e.g. DEV_STAGING
  Our rule:
    - prod target  -> use the custom schema as-is            e.g. STAGING, CORE
    - any other    -> prefix with the target schema          e.g. DEV_STAGING
  This keeps each developer's objects isolated while prod stays clean.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
