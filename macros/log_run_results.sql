{#
  Called from on-run-end. `results` holds one object per node that ran.
  Writes an audit row per model/test/seed into AUDIT.DBT_RUN_LOG.
#}
{% macro log_run_results(results) %}
    {% if execute and results | length > 0 %}
        {% set rows = [] %}
        {% for res in results %}
            {% do rows.append(
                "('" ~ invocation_id ~ "', '" ~ res.node.unique_id ~ "', '" ~ res.status ~ "', "
                ~ (res.execution_time or 0) ~ ", '" ~ target.name ~ "', current_timestamp())"
            ) %}
        {% endfor %}
        insert into {{ target.database }}.audit.dbt_run_log
            (invocation_id, node_id, status, execution_seconds, target_name, logged_at)
        values {{ rows | join(',\n') }}
    {% else %}
        select 1
    {% endif %}
{% endmacro %}
