with source as (

    select * from {{ source('bronze', 'sprints') }}

)

select * from source