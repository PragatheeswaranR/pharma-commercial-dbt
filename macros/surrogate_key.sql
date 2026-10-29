{#
  Builds a deterministic hash key from several columns.
  Same idea as dbt_utils.generate_surrogate_key — written by hand so you see how it works.
  Usage: {{ surrogate_key(['hcp_id', 'product_id', 'week_ending_date']) }}
#}
{% macro surrogate_key(columns) -%}
    md5(concat_ws('||',
        {%- for col in columns %}
        coalesce(cast({{ col }} as varchar), '_null_'){{ "," if not loop.last }}
        {%- endfor %}
    ))
{%- endmacro %}
