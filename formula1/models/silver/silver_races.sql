{{
    config(
        alias='races',
        unique_key=['season', 'round'],
        incremental_strategy='merge',
        merge_update_columns=[
            'race_name', 'race_date', 'circuit_id',
            'ingestion_timestamp', 'source_file', 'batch_id', 'updated_timestamp'
        ]
    )
}}


with source as (

    select * from {{ ref('bronze_races') }}

),

renamed as (

    select
        season,
        round,
        raceName as race_name,
        date     as race_date,
        circuitId as circuit_id,
        ingestion_timestamp,
        source_file,
        batch_id
    from source

),

latest_results as (
    select
        *,
        row_number() over (
            partition by season, round
            order by batch_id desc
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
        season,
        round,
        initcap(race_name) as race_name,
        race_date,
        circuit_id,
        ingestion_timestamp,
        source_file,
        batch_id,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from deduped

)

select * from final