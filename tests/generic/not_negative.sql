{# Custom generic test: any row returned = a failure. #}
{% test not_negative(model, column_name) %}
    select *
    from {{ model }}
    where {{ column_name }} < 0
{% endtest %}
