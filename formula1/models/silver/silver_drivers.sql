{{
    config(
        alias='drivers',
        unique_key='driver_id',
        incremental_strategy='merge',
        merge_update_columns=[
            'driver_name', 'date_of_birth', 'nationality',
            'ingestion_timestamp', 'source_file', 'batch_id', 'updated_timestamp'
        ]
    )
}}

{% set max_batch_id = get_max_batch_id(this) if is_incremental() else none %}

with source as (

    select * from {{ ref('bronze_drivers') }}

    {% if var('batch_id', none) is not none %}
    where batch_id = '{{ var("batch_id") }}'
    {% elif max_batch_id is not none %}
    where batch_id > '{{ max_batch_id }}'
    {% endif %}

),

renamed as (

    select
        driverId               as driver_id,
        initcap(concat_ws(' ', name.givenName, name.familyName)) as driver_name,
        dateOfBirth             as date_of_birth,
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
            partition by driver_id
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
        driver_id,
        driver_name,
        date_of_birth,
        initcap(nationality)        as nationality,
        ingestion_timestamp,
        source_file,
        batch_id,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from deduped

)

select * from final