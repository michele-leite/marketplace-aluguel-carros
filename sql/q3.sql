-- ============================================================
-- Q3: LTV (Lifetime Value) por cohort de primeiro acesso
-- Cohort baseado na primeira sessão (dim_users)
-- ============================================================

with cohort as (

select
    user_id,
    date_trunc('month', first_session_at) as cohort_month
from public_marts_core.dim_users

),

revenue as (

select
    user_id,
    sum(gross_revenue_amt) as lifetime_revenue
from public_marts_core.fct_bookings
group by 1

)

select
c.cohort_month,

count(distinct c.user_id) as users,

sum(coalesce(r.lifetime_revenue,0)) as total_ltv,

round(
    sum(coalesce(r.lifetime_revenue,0))::numeric
    / nullif(count(distinct c.user_id),0),
2) as avg_ltv_per_user

from cohort c
left join revenue r
on c.user_id = r.user_id

group by 1
order by 1;