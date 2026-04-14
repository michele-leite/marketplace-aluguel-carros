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
        p.partner_id as valid_partner_id

    from base b
    left join partners p
        on b.partner_id = p.partner_id

),

rules as (

    select
        *,

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

)

select 
    *,
    case when total_amount_amt > 15000 then true else false end as is_outlier_high_value_flag
from rules
where is_valid_date_flag = true
and is_valid_revenue_flag = true
and is_valid_partner_flag = true