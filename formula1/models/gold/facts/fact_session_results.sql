{{
    config(
        unique_key=['season', 'round', 'constructor_id', 'driver_id', 'session_type'],
        incremental_strategy='merge',
        merge_update_columns=[
            'grid_position', 'completed_laps', 'car_number', 'points',
            'final_position', 'final_position_text', 'status',
            'is_win', 'is_podium', 'has_points', 'is_pole', 'updated_timestamp'
        ]
    )
}}

{% set max_race_ts   = get_max_updated_timestamp(this, "session_type = 'RACE'")   if is_incremental() else none %}
{% set max_sprint_ts = get_max_updated_timestamp(this, "session_type = 'SPRINT'") if is_incremental() else none %}

with results as (

    select
        season,
        round,
        constructor_id,
        driver_id,
        grid_position,
        completed_laps,
        car_number,
        points,
        final_position,
        final_position_text,
        status,
        batch_id,
        'RACE' as session_type
    from {{ ref('silver_results') }}

    {% if max_race_ts is not none %}
    where updated_timestamp > '{{ max_race_ts }}'
    {% endif %}

),

sprints as (

    select
        season,
        round,
        constructor_id,
        driver_id,
        grid_position,
        completed_laps,
        car_number,
        points,
        final_position,
        final_position_text,
        status,
        batch_id,
        'SPRINT' as session_type
    from {{ ref('silver_sprints') }}

    {% if max_sprint_ts is not none %}
    where updated_timestamp > '{{ max_sprint_ts }}'
    {% endif %}

),

unioned as (

    select * from results
    union all
    select * from sprints

),

final as (

    select
        season,
        round,
        constructor_id,
        driver_id,
        session_type,
        grid_position,
        completed_laps,
        car_number,
        points,
        final_position,
        final_position_text,
        status,
        coalesce(final_position = 1, false)             as is_win,
        coalesce(final_position between 1 and 3, false) as is_podium,
        coalesce(points > 0, false)                     as has_points,
        coalesce(grid_position = 1, false)              as is_pole,
        current_timestamp()         as created_timestamp,
        current_timestamp()         as updated_timestamp
    from unioned

)

select * from final