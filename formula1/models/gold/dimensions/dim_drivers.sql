-- Gold: dim_drivers. See models/gold/_gold__models.yml for docs + tests.

{{
    config(
        unique_key='driver_id',
        incremental_strategy='merge',
        merge_update_columns=[
            'driver_name', 'date_of_birth', 'nationality',
            'nationality_region', 'updated_timestamp'
        ]
    )
}}

with drivers as (

    select * from {{ ref('silver_drivers') }}

),

nationality_region as (

    select * from {{ source('gold_reference', 'ref_nationality_region') }}

),

final as (

    select
        drivers.driver_id,
        drivers.driver_name,
        drivers.date_of_birth,
        drivers.nationality,
        nationality_region.region   as nationality_region,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from drivers
    left join nationality_region
        on drivers.nationality = nationality_region.nationality

)

select * from final