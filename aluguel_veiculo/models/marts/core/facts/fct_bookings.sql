{{
    config(
        materialized='incremental',
        unique_key='booking_id',
        incremental_strategy='delete+insert'
    )
}}

with bookings_inc as (
    select * from {{ ref('int_valid_bookings') }}
    {% if is_incremental() %}
    -- Usamos lookback de 7 dias para capturar mudanças de status (cancelamentos)
    where tsp_booked >= (select max(tsp_booked) from {{ this }}) - interval '7 days'
    {% endif %}
),

partners as (
    select * from {{ ref('int_partners') }}
),

sessions as (
    select
        session_id,
        channel_name,
        device_type,
        country_code
    from {{ ref('int_valid_sessions') }}
),

cancellations as (
    select * from {{ ref('int_cancellations') }}
),

joined as (
    select
        b.booking_id,
        b.session_id,
        b.user_id,
        b.partner_id,
        b.tsp_booked,
        b.dt_pickup,
        b.dt_dropoff,
        b.total_amount_amt,
        b.daily_rate_amt,
        b.total_amount_brl_amt,
        b.daily_rate_brl_amt,
        b.is_missing_fx_rate_flag,
        b.booking_status,
        b.pickup_location_name,
        b.car_category_name,
        b.currency_code,
        b.payment_method_name,

        -- dimensões
        s.channel_name,
        s.device_type,
        s.country_code as session_country,

        p.partner_name,
        p.tier_name,
        p.commission_rate_num,
        p.commission_tier_name,

        -- cancelamento
        c.cancellation_id,
        c.refund_amount_amt,
        c.is_refund_anomaly_flag,
        c.is_late_cancellation_flag,

        -- flags de negócio
        case 
            when b.booking_status in ('confirmed', 'completed') then 1 
            else 0 
        end as is_gross_booking_flag,
        
        case 
            when b.booking_status = 'completed' then 1 
            else 0 
        end as is_realized_booking_flag,
        
        case 
            when b.booking_status = 'cancelled' then 1 
            else 0 
        end as is_cancelled_booking_flag,
        
        case 
            when c.cancellation_id is not null then 1 
            else 0 
        end as has_cancellation_flag,

        -- financeiro (valores originais)
        case 
            when b.booking_status in ('confirmed', 'completed') then b.total_amount_amt 
            else 0 
        end as gross_revenue_amt,
        
        case 
            when b.booking_status in ('confirmed', 'completed') then b.total_amount_amt * p.commission_rate_num 
            else 0 
        end as commission_revenue_amt,

        -- financeiro (normalizado BRL)
        case 
            when b.booking_status in ('confirmed', 'completed') then b.total_amount_brl_amt 
            else 0 
        end as gross_revenue_brl_amt,
        
        case 
            when b.booking_status in ('confirmed', 'completed') then b.total_amount_brl_amt * p.commission_rate_num 
            else 0 
        end as commission_revenue_brl_amt,
        
        case 
            when b.is_outlier_high_value_flag then 1 
            else 0 
        end as is_high_value_booking

    from bookings_inc b
    left join partners p 
        on b.partner_id = p.partner_id
    left join sessions s 
        on b.session_id = s.session_id
    left join cancellations c 
        on b.booking_id = c.booking_id
),

final_dedup as (
    -- DEDUPLICAÇÃO FINAL: Garante unicidade por booking_id após os joins usando sintaxe nativa do Postgres
    select distinct on (booking_id)
        *
    from joined
    order by booking_id, tsp_booked desc
)

select *
from final_dedup