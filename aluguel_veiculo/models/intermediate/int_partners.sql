with base as (

    select * 
    from {{ ref('stg_partners') }}

),

rules as (

    select
        partner_id,
        partner_name,
        country_code,
        tier_name,
        partner_status,
        commission_rate_num,
        tsp_created,
        tsp_updated,
        email,
        case 
            when partner_status = 'active' then true 
            else false 
        end as is_active_partner_flag,
        case 
            when commission_rate_num between 0.05 and 0.30 then true
            else false
        end as is_valid_commission_flag,
        case
            when commission_rate_num >= 0.20 then 'high'
            when commission_rate_num >= 0.10 then 'medium'
            else 'low'
        end as commission_tier_name

    from base

)

select * 
from rules