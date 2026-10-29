{#
  Called from on-run-end. dbt's `grants` config grants SELECT on tables/views,
  but a role also needs USAGE on the schema to see them. This loops over every
  schema the run touched and grants usage.
  `database_schemas` is a list of (database, schema) pairs, only available in on-run-end.
#}
{% macro grant_schema_usage(database_schemas, role_name) %}
    {% if execute %}
        {% for (database, schema) in database_schemas %}
            {% do run_query('grant usage on schema ' ~ database ~ '.' ~ schema ~ ' to role ' ~ role_name) %}
            {% do log('Granted usage on ' ~ database ~ '.' ~ schema ~ ' to ' ~ role_name, info=true) %}
        {% endfor %}
    {% endif %}
    select 1
{% endmacro %}
