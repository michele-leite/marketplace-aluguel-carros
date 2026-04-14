{{ config(materialized='table') }}

with sessions as (

    select *
    from {{ ref('fct_sessions') }}

),

aggregated as (

    select

        -- dimensão temporal
        date_trunc('day', tsp_started) as dt_date,

        -- dimensões de negócio
        channel_name,
        device_type,
        country_code,

        -- volume
        count(*) as nr_sessions,

        -- comportamento
        sum(has_search_flag) as nr_sessions_with_search,
        sum(nr_searches) as nr_total_searches,

        -- conversão
        sum(has_booking_flag) as nr_sessions_with_booking,
        sum(has_valid_booking_flag) as nr_sessions_with_valid_booking,

        -- receita
        sum(total_revenue_amt) as total_revenue_amt,

        -- engajamento médio
        avg(nr_searches) as avg_searches_per_session,

        -- flags derivadas úteis
        sum(case when engagement_level = 'high' then 1 else 0 end) as nr_high_engagement_sessions

    from sessions

    group by 1,2,3,4

),

final as (

    select

        *,

        -- taxas do funil
        case when nr_sessions > 0 
            then nr_sessions_with_search * 1.0 / nr_sessions 
        end as search_rate,

        case when nr_sessions > 0 
            then nr_sessions_with_booking * 1.0 / nr_sessions 
        end as booking_rate,

        case when nr_sessions_with_search > 0 
            then nr_sessions_with_booking * 1.0 / nr_sessions_with_search 
        end as search_to_booking_rate,

        case when nr_sessions > 0 
            then total_revenue_amt * 1.0 / nr_sessions 
        end as revenue_per_session,

        case when nr_sessions_with_booking > 0 
            then total_revenue_amt * 1.0 / nr_sessions_with_booking 
        end as avg_ticket

    from aggregated

)

select *
from final