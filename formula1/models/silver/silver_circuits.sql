-- Silver: Drivers. See models/silver/_silver__models.yml for docs + tests.

{{
    config(
        alias='circuits',
        unique_key='circuit_id',
        incremental_strategy='merge',
        merge_update_columns=[

            'circuit_name', 'latitude', 'longitude', 'locality', 'country',
            'ingestion_timestamp', 'source_file', 'batch_id', 'updated_timestamp'
        ]
    )
}}

{% set max_batch_id = get_max_batch_id(this) if is_incremental() else none %}

with source as (

    select * from {{ ref('bronze_circuits') }}

    {% if var('batch_id', none) is not none %}
    where batch_id = '{{ var("batch_id") }}'
    {% elif max_batch_id is not none %}
    where batch_id > '{{ max_batch_id }}'
    {% endif %}

),

renamed as (

    select
        circuitId   as circuit_id,
        circuitName as circuit_name,
        lat         as latitude,
        long        as longitude,
        locality,
        country,
        ingestion_timestamp,
        source_file,
        batch_id
    from source

),

valid as (

    select * from renamed
    where circuit_id is not null

),

latest_results as (
    select
        *,
        row_number() over (
            partition by circuit_id
            order by batch_id desc, ingestion_timestamp desc
        ) as rn
    from valid
),

deduped as (
    select *
    from latest_results
    where rn = 1

),

final as (

    select
        circuit_id,
        initcap(circuit_name) as circuit_name,
        latitude,
        longitude,
        initcap(locality)     as locality,
        country,
        ingestion_timestamp,
        source_file,
        batch_id,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from deduped

)

select * from final