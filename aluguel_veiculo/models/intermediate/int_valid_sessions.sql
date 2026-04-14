with base as (
    select * from {{ ref('stg_sessions') }}
),

calc as (
    select
        *,
        case 
            when tsp_ended >= tsp_started
            then floor(extract(epoch from (tsp_ended - tsp_started)) / 60)
            else null
        end as nr_session_duration_minutes,
        case 
            when user_id is null then true 
            else false 
        end as is_anonymous_user_flag
    from base
)

select 
    *,
    case when nr_session_duration_minutes between 0 and 1440  then true else false end as is_24h_session_duration_flag
from calc