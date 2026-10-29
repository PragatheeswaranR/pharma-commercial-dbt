{# Custom generic test with arguments. Usage in YAML:
     - value_between:
         min_value: 1
         max_value: 10
#}
{% test value_between(model, column_name, min_value, max_value) %}
    select *
    from {{ model }}
    where {{ column_name }} < {{ min_value }}
       or {{ column_name }} > {{ max_value }}
{% endtest %}
