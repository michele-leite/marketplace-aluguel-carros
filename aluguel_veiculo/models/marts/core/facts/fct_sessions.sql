{{ config(
    materialized='incremental',
    unique_key='session_id',
    incremental_strategy='delete+insert',
    partition_by={"field": "dt_session", "data_type": "date"}
) }}

with sessions as (

    select *
    from {{ ref('int_valid_sessions') }}

),
final_sessions as (
    select
        *,
        cast(tsp_started as date) as dt_session,
        -- Lógica para não perder os 0,5%
        case 
            when tsp_ended is not null then tsp_ended -- Dado real
            when current_timestamp > tsp_started + interval '1440 minutes' 
                then tsp_started + interval '1440 minutes' -- Fecha "na marra" após 24h
            else null -- Mantém aberta se tiver < 1440 min
        end as tsp_ended_final
    from sessions
),
sessions_inc as (
    select *
    from final_sessions

    {% if is_incremental() %}

    where (
        -- Captura sessões que terminaram ou foram "forçadas" a fechar
        tsp_ended_final > (select max(tsp_ended_final) from {{ this }}) - interval '7 days'
        -- Captura sessões novas que ainda estão abertas (null)
        or tsp_ended_final is null
    )
    -- Lookback de segurança para o merge encontrar os IDs antigos e atualizar
    and dt_session >= current_date - interval '10 days'

    {% endif %}
),
searches as (

    select
        session_id,
        count(*) as nr_searches,
        max(nr_searches_5min) as max_search_intensity
    from {{ ref('int_valid_searches') }}
    group by session_id

),

bookings as (

    select
        session_id,
        count(*) as nr_bookings,
        sum(case when booking_status in ('confirmed','completed') then 1 else 0 end) as nr_valid_bookings,
        sum(case when booking_status = 'completed' then 1 else 0 end) as nr_completed_bookings,
        sum(total_amount_amt) as total_revenue_amt
    from {{ ref('int_valid_bookings') }}
    group by session_id

),

joined as (

    select
        s.session_id,
        s.user_id,

        -- tempo
        s.tsp_started,
        s.tsp_ended,
        s.nr_session_duration_minutes,
        s.dt_session,
        s.tsp_ended_final,

        -- aquisição
        s.channel_name,
        s.device_type,
        s.country_code,
        s.utm_source,
        s.utm_campaign,

        s.is_bot_flag,
        s.page_views_qty,

        -- comportamento
        coalesce(se.nr_searches, 0) as nr_searches,
        coalesce(se.max_search_intensity, 0) as max_search_intensity,

        -- conversão
        coalesce(b.nr_bookings, 0) as nr_bookings,
        coalesce(b.nr_valid_bookings, 0) as nr_valid_bookings,
        coalesce(b.nr_completed_bookings, 0) as nr_completed_bookings,

        -- receita
        coalesce(b.total_revenue_amt, 0) as total_revenue_amt,

        -- flags principais
        case when se.nr_searches > 0 then 1 else 0 end as has_search_flag,
        case when b.nr_bookings > 0 then 1 else 0 end as has_booking_flag,
        case when b.nr_valid_bookings > 0 then 1 else 0 end as has_valid_booking_flag,

        -- conversão (nível sessão)
        case 
            when se.nr_searches > 0 and b.nr_valid_bookings > 0 then 1
            else 0
        end as is_converted_session,

        -- classificação de engajamento
        case 
            when se.nr_searches = 0 then 'no_search'
            when se.nr_searches <= 2 then 'low'
            when se.nr_searches <= 5 then 'medium'
            else 'high'
        end as engagement_level,
        s.is_24h_session_duration_flag

    from sessions_inc s

    left join searches se
        on s.session_id = se.session_id

    left join bookings b
        on s.session_id = b.session_id

),
final_dedup as (
    -- Limpa o fan-out dos joins
    select * from (
        select *, row_number() over (partition by session_id order by tsp_started desc) as rn
        from joined
    ) sub where rn = 1
)

select * from final_dedup

