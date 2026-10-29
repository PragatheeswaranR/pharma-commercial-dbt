{# Turns '  JOHN ' / 'john' / 'John' into 'John' #}
{% macro clean_name(column_name) -%}
    initcap(trim({{ column_name }}))
{%- endmacro %}
