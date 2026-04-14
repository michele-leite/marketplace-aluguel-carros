
-- ============================================================
-- Q1: Taxa de conversão por funil (sessão → busca → reserva)
-- Segmentação: país + device
-- Fonte: fct_sessions (já possui flags agregadas por sessão)
-- ============================================================


with base as (

select
    country_code,
    device_type,

    count(*) as sessions,

    -- sessões com busca
    sum(has_search_flag) as sessions_with_search,

    -- sessões com booking válido
    sum(has_valid_booking_flag) as sessions_with_booking

from public_marts_core.fct_sessions
group by 1,2


)

select
country_code,
device_type,


sessions,
sessions_with_search,
sessions_with_booking,

-- conversão sessão → busca
round(sessions_with_search::numeric / nullif(sessions,0), 4) as session_to_search,

-- conversão busca → booking
round(sessions_with_booking::numeric / nullif(sessions_with_search,0), 4) as search_to_booking,

-- conversão total
round(sessions_with_booking::numeric / nullif(sessions,0), 4) as session_to_booking


from base
order by sessions desc;