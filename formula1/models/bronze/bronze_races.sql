with source as (

    select * from {{ source('bronze', 'races') }}

)

select * from source