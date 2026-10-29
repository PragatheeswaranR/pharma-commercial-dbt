-- Staging = 1:1 with a source table. Rename, cast, clean, dedupe. No joins, no business logic.
with source as (

    select * from {{ source('pharma_raw', 'hcps') }}

),

deduped as (

    -- the vendor sends multiple versions of an HCP; keep the most recent one
    select *
    from source
    qualify row_number() over (partition by hcp_npi order by _loaded_at desc) = 1

),

cleaned as (

    select
        hcp_npi                                  as hcp_id,
        {{ clean_name('first_nm') }}             as first_name,
        {{ clean_name('last_nm') }}              as last_name,
        upper(trim(specialty_cd))                as specialty_code,
        terr_id                                  as territory_id,
        upper(trim(state_cd))                    as state_code,
        decile_rank::number(2,0)                 as decile,
        lower(trim(email_addr))                  as email,
        _loaded_at                               as loaded_at
    from deduped

)

select * from cleaned
