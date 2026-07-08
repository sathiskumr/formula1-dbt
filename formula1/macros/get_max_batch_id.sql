{% macro get_max_batch_id(relation) %}

    {% set query %}
        select max(batch_id) as batch_id from {{ relation }}
    {% endset %}

    {% set results = run_query(query) %}

    {% if execute %}
        {% set max_batch_id = results.columns[0].values()[0] %}
        {{ return(max_batch_id) }}
    {% else %}
        {{ return(none) }}
    {% endif %}

{% endmacro %}