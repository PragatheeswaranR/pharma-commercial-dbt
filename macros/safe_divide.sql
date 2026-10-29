{# Returns null instead of a divide-by-zero error #}
{% macro safe_divide(numerator, denominator) -%}
    case when ({{ denominator }}) is null or ({{ denominator }}) = 0 then null
         else ({{ numerator }}) / ({{ denominator }}) end
{%- endmacro %}
