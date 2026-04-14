with src as (
    select * from {{ source('raw','raw_partners') }}
),

dedup as (
    select *,
           row_number() over (partition by partner_id order by updated_at desc nulls last) as rn
    from src
)

select
    cast(partner_id as text) as partner_id,
    cast(lower(partner_name) as text) as partner_name,
    cast(upper(country) as text) as country_code,
    cast(lower(tier) as text) as tier_name,
    cast(lower(status) as text) as partner_status,
    cast(commission_rate as numeric) as commission_rate_num,
    cast(created_at as timestamp) as tsp_created,
    cast(updated_at as timestamp) as tsp_updated,
    cast(contact_email as text) as email
from dedup
where rn = 1