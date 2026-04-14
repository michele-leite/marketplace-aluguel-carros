with base as (
    select * from {{ ref('int_partners') }}
)

select *
from base