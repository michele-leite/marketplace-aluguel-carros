with base as (

    select * from {{ ref('stg_cancellations') }}

),

bookings as (

    select booking_id, total_amount_amt
    from {{ ref('stg_bookings') }}

),
-- rule 1: join de integridade
joined as (

    select
        c.*,
        b.total_amount_amt

    from base c
    inner join bookings b -- não vai existir cancelamento sem reserva válida
        on c.booking_id = b.booking_id

),

final as (

    select
        *,
--  rule 3: refund > total
        case 
            when refund_amount_amt > total_amount_amt then true 
            else false 
        end as is_refund_anomaly_flag,
--  rule 2: late cancellation
        case 
            when days_before_pickup_qty < 0 then true
            else false
        end as is_late_cancellation_flag

    from joined

)

select * from final