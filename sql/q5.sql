-- Q5: Taxa de cancelamento por parceiro + detecção de outliers
-- Método: Z-score (> 2 desvios padrão)
-- ============================================================

with base as (

select
    partner_id,
    partner_name,

    count(*) as total_bookings,
    sum(is_cancelled_booking_flag) as total_cancellations

from public_marts_core.fct_bookings
group by 1,2

),
rates as (

select
    *,
    total_cancellations::numeric / nullif(total_bookings,0) as cancellation_rate
from base

),

stats as (

select
    avg(cancellation_rate) as avg_rate,
    stddev_pop(cancellation_rate) as std_rate
from rates
)

select
r.*,

s.avg_rate,
s.std_rate,

-- cálculo do z-score
(r.cancellation_rate - s.avg_rate) / nullif(s.std_rate,0) as z_score,

-- flag de outlier
case
    when abs((r.cancellation_rate - s.avg_rate) / nullif(s.std_rate,0)) > 2
    then 1 else 0
end as is_outlier_flag

from rates r
cross join stats s

order by cancellation_rate desc;
