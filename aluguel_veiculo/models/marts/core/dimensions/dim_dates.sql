{{ config(materialized='table') }}

with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2024-01-01' as date)",
        end_date="cast('2026-12-31' as date)"
    ) }}

),

final as (

    select
        date_day as dt_date,

        extract(year from date_day) as nr_year,
        extract(month from date_day) as nr_month,
        extract(day from date_day) as nr_day,

        to_char(date_day, 'YYYY-MM') as ds_year_month,
        to_char(date_day, 'Month') as ds_month_name,
        to_char(date_day, 'Day') as ds_weekday_name,

        extract(dow from date_day) as nr_weekday,

        case 
            when extract(dow from date_day) in (0,6) then true
            else false
        end as fl_is_weekend

    from date_spine

)

select * from final