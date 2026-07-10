{{
    config(
        alias='results',
        unique_key=['season', 'round', 'constructor_id', 'driver_id'],
        incremental_strategy='merge',
        merge_update_columns=[
            'race_name', 'race_date', 'grid_position', 'completed_laps',
            'car_number', 'points', 'final_position', 'final_position_text',
            'status', 'ingestion_timestamp', 'source_file', 'batch_id', 'updated_timestamp'
        ]
    )
}}

{% set max_batch_id = get_max_batch_id(this) if is_incremental() else none %}

with source as (

    select * from {{ ref('bronze_results') }}

    {% if var('batch_id', none) is not none %}
    where batch_id = '{{ var("batch_id") }}'
    {% elif max_batch_id is not none %}
    where batch_id > '{{ max_batch_id }}'
    {% endif %}

),

renamed as (

    select
        season,
        round,
        constructorId    as constructor_id,
        driverId         as driver_id,
        date             as race_date,
        raceName         as race_name,
        grid             as grid_position,
        laps             as completed_laps,
        number           as car_number,
        points,
        position         as final_position,
        positionText     as final_position_text,
        status,
        ingestion_timestamp,
        source_file,
        batch_id
    from source

),

valid as (

    select * 
    from renamed
    where season is not null
      and round is not null
      and constructor_id is not null
      and driver_id is not null

),

latest_results as (
    select
        *,
        row_number() over (
            partition by season, round, constructor_id, driver_id
            order by batch_id desc
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
        season,
        round,
        constructor_id,
        driver_id,
        race_date,
        initcap(race_name) as race_name,
        grid_position,
        completed_laps,
        car_number,
        points,
        final_position,
        final_position_text,
        status,
        ingestion_timestamp,
        source_file,
        batch_id,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from deduped

)

select * from final