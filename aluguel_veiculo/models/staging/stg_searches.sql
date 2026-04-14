with src as (
    select * from {{ source('raw','raw_searches') }}
),

dedup as (
    select *,
           row_number() over (partition by search_id order by searched_at desc) as rn
    from src
)

select
    cast(search_id as text) as search_id,
    cast(session_id as text) as session_id,
    cast(searched_at as timestamp) as tsp_searched,
    cast(initcap(pickup_location) as text) as pickup_location_name,
    cast(initcap(dropoff_location) as text) as dropoff_location_name,
    cast(pickup_date as date) as dt_pickup,
    cast(dropoff_date as date) as dt_dropoff,
    cast(lower(car_category) as text) as car_category_name,
    cast(num_results as integer) as results_qty,
    cast(partner_id_clicked as text) as partner_id_clicked,
    cast(price_shown as numeric) as price_shown_amt
from dedup
where rn = 1
and (dropoff_date is null or dropoff_date >= pickup_date)