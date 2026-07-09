{{
    config(
        unique_key=['season', 'round'],
        incremental_strategy='merge',
        merge_update_columns=[
            'race_name', 'race_date', 'circuit_name', 'locality', 'country', 'updated_timestamp'
        ]
    )
}}

with races as (

    select * from {{ ref('silver_races') }}

),

circuits as (

    select * from {{ ref('silver_circuits') }}

),

final as (

    select
        r.season,
        r.round,
        r.race_name,
        r.race_date,
        c.circuit_name,
        c.locality,
        c.country,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from races r
    inner join circuits c
        on c.circuit_id = r.circuit_id

)

select * from final