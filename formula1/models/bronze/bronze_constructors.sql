with source as (

    select * from {{ source('bronze', 'constructors') }}

)

select * from source