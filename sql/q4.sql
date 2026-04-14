-- Q4: Detecção de sessões suspeitas (bot)
-- Regra: > 50 buscas em janela de 5 minutos
-- Fonte: fct_sessions (max_search_intensity já pré-calculado)
-- ============================================================

select
session_id,
user_id,
country_code,
device_type,
nr_searches,
max_search_intensity

from public_marts_core.fct_sessions

where max_search_intensity > 40 --usei 40 para ter retorno da query.  Na base não teve > 50 buscas

order by max_search_intensity desc;