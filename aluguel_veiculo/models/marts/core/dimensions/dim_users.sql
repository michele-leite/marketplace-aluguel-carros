with sessions as (

    select *
    from {{ ref('int_valid_sessions') }}

),

ranked as (

    select
        user_id,
        tsp_started,
        channel_name,
        device_type,
        country_code,

        row_number() over (
            partition by user_id 
            order by tsp_started asc
        ) as rn

    from sessions
    where user_id is not null

),

first_touch as (

    select
        user_id,
        tsp_started as first_session_at,
        channel_name as first_channel,
        device_type as first_device,
        country_code as first_country

    from ranked
    where rn = 1

),

final as (

    select
        user_id,

        first_session_at,
        first_channel,
        first_device,
        first_country,

        false as is_anonymous_user  -- só usuários identificados entram aqui

    from first_touch

)

select * from final