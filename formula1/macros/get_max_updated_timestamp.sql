{% macro get_max_updated_timestamp(relation, where_clause=none) %}

    {% set query %}
        select max(updated_timestamp) as updated_timestamp
        from {{ relation }}
        {% if where_clause %}
        where {{ where_clause }}
        {% endif %}
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute %}
        {% set max_ts = results.columns[0].values()[0] %}
        {{ return(max_ts) }}
    {% else %}
        {{ return(none) }}
    {% endif %}

{% endmacro %}