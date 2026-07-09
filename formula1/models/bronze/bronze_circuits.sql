with source as (

    select * from {{ source('bronze', 'circuits') }}

)

select * from source