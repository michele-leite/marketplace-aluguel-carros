with src as (
    select * from {{ source('raw','raw_cancellations') }}
),

dedup as (
    select *,
           row_number() over (partition by cancellation_id order by cancelled_at desc) as rn
    from src
)

select
    cast(cancellation_id as text) as cancellation_id,
    cast(booking_id as text) as booking_id,
    cast(cancelled_at as timestamp) as tsp_cancelled,
    cast(coalesce(reason,'unknown') as text) as cancellation_reason,
    cast(coalesce(cancelled_by,'unknown') as text) as cancelled_by,
    cast(refund_amount as numeric) as refund_amount_amt,
    cast(coalesce(refund_status,'unknown') as text) as refund_status,
    cast(days_before_pickup as integer) as days_before_pickup_qty
from dedup
where rn = 1