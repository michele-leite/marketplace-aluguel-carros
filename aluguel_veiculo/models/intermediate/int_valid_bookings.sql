with base as (

    select * from {{ ref('stg_bookings') }}

),

partners as (

    select *
    from {{ ref('int_partners') }}
    where is_active_partner_flag = true

),

joined as (

    select
        b.*,
        p.partner_id as valid_partner_id,
        fx.exchange_rate

    from base b
    left join partners p
        on b.partner_id = p.partner_id
    left join lateral (

        select fx_inner.exchange_rate
        from {{ ref('dim_exchange_rates') }} fx_inner
        where fx_inner.from_currency_code = upper(trim(b.currency_code))
          and fx_inner.to_currency_code = 'BRL'
          and fx_inner.date_day <= b.tsp_booked::date
        order by fx_inner.date_day desc
        limit 1

    ) fx on true

),

rules as (

    select
        *,

        -- fx: taxa aplicada (last known rate)
        case
            when upper(trim(currency_code)) = 'BRL' then 1
            else exchange_rate
        end as applied_fx_rate,

        -- rule 1: datas
        case 
            when dt_dropoff >= dt_pickup then true
            else false
        end as is_valid_date_flag,

        -- rule 2:  revenue por status
        case 
            when booking_status in ('confirmed','completed') 
                 and total_amount_amt > 0 then true
            when booking_status not in ('confirmed','completed') then true
            else false
        end as is_valid_revenue_flag,

        -- rule 3: parceiro válido
        case 
            when valid_partner_id is not null then true
            else false
        end as is_valid_partner_flag

    from joined

),

with_fx as (

    select
        *,

        -- valores convertidos para BRL
        total_amount_amt * applied_fx_rate as total_amount_brl_amt,
        daily_rate_amt * applied_fx_rate as daily_rate_brl_amt,

        -- flag de qualidade: câmbio ausente
        case when applied_fx_rate is null then true else false end as is_missing_fx_rate_flag

    from rules

)

select 
    *,
    case when total_amount_amt > 15000 then true else false end as is_outlier_high_value_flag
from with_fx
where is_valid_date_flag = true
and is_valid_revenue_flag = true
and is_valid_partner_flag = true