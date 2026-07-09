{{
    config(
        unique_key='constructor_id',
        incremental_strategy='merge',
        merge_update_columns=[
            'constructor_name', 'nationality', 'nationality_region'
        ]
    )
}}

with constructors as (

    select * from {{ ref('silver_constructors') }}

),

nationality_region as (

    select * from {{ source('gold_reference', 'ref_nationality_region') }}

),

final as (

    select
        constructors.constructor_id,
        constructors.constructor_name,
        constructors.nationality,
        nationality_region.region as nationality_region,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from constructors
    left join nationality_region
        on constructors.nationality = nationality_region.nationality

)

select * from final