with source as (

    select * from {{ source('bronze', 'drivers') }}

)

select * from source