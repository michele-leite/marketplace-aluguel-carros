with src as (
    select * from {{ source('raw','raw_sessions') }}
),

filtered as (
    select *
    from src
    where is_bot = false
),

dedup as (
    select *,
           row_number() over (partition by session_id order by started_at desc) as rn
    from filtered
)

select
    cast(session_id as text) as session_id,
    cast(user_id as text) as user_id,
    cast(lower(channel) as text) as channel_name,
    cast(lower(device) as text) as device_type,
    cast(upper(country) as text) as country_code,
    cast(is_bot as boolean) as is_bot_flag,
    cast(started_at as timestamp) as tsp_started,
    cast(ended_at as timestamp) as tsp_ended,
    cast(page_views as integer) as page_views_qty,
    cast(coalesce(utm_source,'unknown') as text) as utm_source,
    cast(coalesce(utm_campaign,'unknown') as text) as utm_campaign
from dedup
where rn = 1