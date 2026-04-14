with src as (
    select * from {{ source('raw','raw_bookings') }}
),

dedup as (
    select *,
           row_number() over (partition by booking_id order by booked_at desc) as rn
    from src
)

select
    cast(booking_id as text) as booking_id,
    cast(session_id as text) as session_id,
    cast(user_id as text) as user_id,
    cast(partner_id as text) as partner_id,
    cast(booked_at as timestamp) as tsp_booked,
    cast(pickup_date as date) as dt_pickup,
    cast(dropoff_date as date) as dt_dropoff,
    cast(initcap(pickup_location) as text) as pickup_location_name,
    cast(lower(car_category) as text) as car_category_name,
    cast(daily_rate as numeric) as daily_rate_amt,
    cast(total_amount as numeric) as total_amount_amt,
    cast(currency as text) as currency_code,
    cast(lower(status) as text) as booking_status,
    cast(coalesce(payment_method,'unknown') as text) as payment_method_name
from dedup
where rn = 1
and total_amount > 0