{# '2026-Q3' style label. Change here once if the fiscal calendar ever changes. #}
{% macro fiscal_quarter(date_column) -%}
    year({{ date_column }}) || '-Q' || quarter({{ date_column }})
{%- endmacro %}
