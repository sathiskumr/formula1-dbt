
{{
    config(
        alias='constructors',
        unique_key='constructor_id',
        incremental_strategy='merge',
        merge_update_columns=[
            'constructor_name', 'nationality',
            'ingestion_timestamp', 'source_file', 'batch_id', 'updated_timestamp'
        ]
    )
}}

{% set max_batch_id = get_max_batch_id(this) if is_incremental() else none %}

with source as (

    select * from {{ ref('bronze_constructors') }}

    {% if var('batch_id', none) is not none %}
    where batch_id = '{{ var("batch_id") }}'
    {% elif max_batch_id is not none %}
    where batch_id > '{{ max_batch_id }}'
    {% endif %}

),


renamed as (

    select
        constructorId as constructor_id,
        name          as constructor_name,
        nationality,
        ingestion_timestamp,
        source_file,
        batch_id
    from source

),

latest_results as (
    select
        *,
        row_number() over (
            partition by constructor_id
            order by batch_id desc, ingestion_timestamp desc
        ) as rn
    from renamed
),

deduped as (
    select *
    from latest_results
    where rn = 1

),

final as (

    select
        constructor_id,
        constructor_name,
        initcap(nationality) as nationality,
        ingestion_timestamp,
        source_file,
        batch_id,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from deduped

)

select * from final