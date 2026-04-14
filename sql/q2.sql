
-- Q2: Top 10 parceiros por receita nos últimos 90 dias
-- Regra: excluir cancelamentos
-- Fonte: fct_bookings (já possui flags e revenue tratados)

with filtered as (

select
    partner_id,
    partner_name,
    gross_revenue_amt

from public_marts_core.fct_bookings

where
    tsp_booked >= '2025-03-31':: date - interval '90 days'
    and is_cancelled_booking_flag = 0

),

agg as (
select
    partner_id,
    partner_name,
    sum(gross_revenue_amt) as total_revenue,
    count(*) as total_bookings

from filtered
group by 1,2

)

select *
from agg
order by total_revenue desc
limit 10;