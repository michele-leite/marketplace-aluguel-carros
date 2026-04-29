{{ config(materialized='table') }}

with source as (

    select * from {{ ref('exchange_rates') }}

),

final as (

    select
        cast(date_day as date) as date_day,
        upper(cast(from_currency_code as text)) as from_currency_code,
        upper(cast(to_currency_code as text)) as to_currency_code,
        cast(exchange_rate as numeric) as exchange_rate

    from source

)

select * from final
