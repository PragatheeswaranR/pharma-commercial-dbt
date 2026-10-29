{# An NPI must be exactly 10 digits. #}
{% test valid_npi(model, column_name) %}
    select *
    from {{ model }}
    where not regexp_like({{ column_name }}, '^[0-9]{10}$')
{% endtest %}
