with source as (

    select * from {{ source('bronze', 'results') }}

)

select * from source