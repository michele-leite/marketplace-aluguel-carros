with base as (

    select * from {{ ref('stg_searches') }}

),

flagged as (

    select
        *,
        count(*) over (
            partition by session_id 
            order by tsp_searched 
            range between interval '5 minutes' preceding and current row
        ) as nr_searches_5min
    from base

),

-- rule 2: remove bots 
sessions as (

    select session_id
    from {{ ref('int_valid_sessions') }}

),

-- rule 3: partners válidos
partners as (

    select partner_id
    from {{ ref('int_partners') }}

),


joined as (

    select
        b.*,
        p.partner_id as valid_partner_id

    from flagged b

    inner join sessions s
        on b.session_id = s.session_id

    left join partners p
        on b.partner_id_clicked = p.partner_id

),


rules as (

    select *
    from joined
    where 
        nr_searches_5min < 50
        and (
            partner_id_clicked is null 
            or valid_partner_id is not null
        )

)

select * from rules