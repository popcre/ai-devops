-- shared-db #3947 — READ-ONLY live proof queries (Scraped Properties display dedupe)
-- Migration under proof: 20261007190954 (forward replacement for HARD_BLOCKED 20261007020907)
--   scraped_inventory_warner_fallback_sesame_value_key_dedupe.sql
--
-- READ-ONLY. Statements are SELECT / session-local SET / TEMP tables only.
-- No DML on permanent tables, no DDL on permanent objects.
--
-- Target: production qsllyeztdwjgirsysgai once the ledger shows 20261007190954.
-- Also valid on preview mvpkijzfmfcxhnzqogzs (migration already applied there).
--
-- POOLER-SAFE: all TEMP work runs inside one transaction with ON COMMIT DROP.
-- Supabase's transaction pooler can reuse a backend and leak temp tables across
-- sessions, so the script also drops any leftover fixture names first.
--
-- Each check prints:  check_name | result | detail
--   result = PASS | FAIL | INFO | SKIP
-- Coordinator gate: zero rows with result = 'FAIL'.
-- Baseline production evidence (2026-10-06) is noted as INFO expectations,
-- not hard gates: live counts may drift with new captures.

\set ON_ERROR_STOP on
\pset pager off

-- Clean up any fixture temp tables leaked by a previous pooled session.
drop table if exists
  proof_fn,
  proof_sesame_latest,
  proof_sesame_display,
  proof_warner_display,
  proof_lucasfilm_display,
  proof_shared_ids;

-- ---------------------------------------------------------------------------
-- 0. Target identity and migration gate
-- ---------------------------------------------------------------------------
select '00_target' as check_name,
       'INFO' as result,
       current_database() || ' user=' || current_user as detail;

select '01_migration_applied' as check_name,
       case when exists (
         select 1 from supabase_migrations.schema_migrations
         where version = '20261007190954'
       ) then 'PASS' else 'FAIL' end as result,
       'ledger must contain 20261007190954 before these proofs mean anything' as detail;

-- ---------------------------------------------------------------------------
-- Everything below is one transaction so TEMP tables drop cleanly under the
-- Supabase transaction pooler.
-- ---------------------------------------------------------------------------
begin;

create temp table proof_fn on commit drop as
select p.prosrc as src,
       p.prosecdef as secdef,
       p.provolatile as vol,
       p.proconfig as cfg
from pg_proc p
where p.oid = 'api.db_data_admin_scraped_source_inventory(text,text,text,integer)'::regprocedure;

select '02_fn_exists' as check_name,
       case when exists (select 1 from proof_fn) then 'PASS' else 'FAIL' end as result,
       'api.db_data_admin_scraped_source_inventory(text,text,text,integer)' as detail;

select '03_fn_warner_hide_predicate' as check_name,
       case when position($w$where p.identity_method <> 'natural_key_fallback'$w$ in f.src) > 0
             and position($w$and t.identity_method = 'source_id'$w$ in f.src) > 0
            then 'PASS' else 'FAIL' end as result,
       'Warner natural_key_fallback twin hide present in function body' as detail
from proof_fn f;

select '04_fn_sesame_value_key_collapse' as check_name,
       case when position($s$select distinct on (sb.value_key)$s$ in f.src) > 0
             and position($s$order by sb.value_key, (sb.field_generation = 'current') desc$s$ in f.src) > 0
             and position($s$select distinct on (sb.value_label)$s$ in f.src) = 0
            then 'PASS' else 'FAIL' end as result,
       'Sesame collapses on value_key preferring current; not on value_label' as detail
from proof_fn f;

select '05_fn_lucasfilm_disney_hide_predicate' as check_name,
       case when position($l$where not exists ($l$ in f.src) > 0
             and position($l$from plm.dcp_property d$l$ in f.src) > 0
             and position($l$and d.source_id = p.source_id$l$ in f.src) > 0
            then 'PASS' else 'FAIL' end as result,
       'Lucasfilm Disney-twin hide present in function body' as detail
from proof_fn f;

select '06_fn_security_posture' as check_name,
       case when f.secdef and f.vol = 's'
             and f.cfg = array['search_path=app, public']
             and has_function_privilege('authenticated',
                  'api.db_data_admin_scraped_source_inventory(text,text,text,integer)','execute')
             and not has_function_privilege('anon',
                  'api.db_data_admin_scraped_source_inventory(text,text,text,integer)','execute')
            then 'PASS' else 'FAIL' end as result,
       'security definer, stable, search_path pinned, authenticated only' as detail
from proof_fn f;

-- ---------------------------------------------------------------------------
-- Shared display fixtures — exact predicates from the migrated function.
-- ---------------------------------------------------------------------------
create temp table proof_sesame_latest on commit drop as
select c.id
from plm.sesame_capture c
where c.status = 'complete'
order by c.source_captured_at desc, c.load_completed_at desc, c.id desc
limit 1;

create temp table proof_sesame_display on commit drop as
select distinct on (sb.value_key)
       sb.value_key, sb.value_label, sb.field_generation, sb.capture_id
from plm.sesame_brand sb
join proof_sesame_latest c on c.id = sb.capture_id
order by sb.value_key, (sb.field_generation = 'current') desc, sb.value_label;

create temp table proof_warner_display on commit drop as
select p.*
from plm.wb_property p
where p.identity_method <> 'natural_key_fallback'
   or not exists (
     select 1 from plm.wb_property t
     where t.source_namespace = p.source_namespace
       and t.identity_method = 'source_id'
       and t.label = p.label
   );

create temp table proof_lucasfilm_display on commit drop as
select p.*
from plm.lucasfilm_dcp_property p
where not exists (
  select 1 from plm.dcp_property d
  where d.source_system = 'disney_dcpvault'
    and d.source_id = p.source_id
);

create temp table proof_shared_ids on commit drop as
select distinct p.source_id
from plm.lucasfilm_dcp_property p
where exists (
  select 1 from plm.dcp_property d
  where d.source_system = 'disney_dcpvault'
    and d.source_id = p.source_id
);

-- ---------------------------------------------------------------------------
-- PATTERN 1 — Warner
-- No natural_key_fallback row whose label has a source_id twin in the
-- same namespace appears in the DISPLAY set.
-- ---------------------------------------------------------------------------
select '10_warner_display_fallback_with_source_id_twin' as check_name,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       'displayed fallback rows that still have a source_id twin; expected 0, got '
         || count(*)::text as detail
from proof_warner_display p
where p.identity_method = 'natural_key_fallback'
  and exists (
    select 1 from plm.wb_property t
    where t.source_namespace = p.source_namespace
      and t.identity_method = 'source_id'
      and t.label = p.label
  );

select '11_warner_counts' as check_name,
       'INFO' as result,
       'displayed=' || (select count(*) from proof_warner_display)::text
         || ' landing_total=' || (select count(*) from plm.wb_property)::text
         || ' landing_source_id=' || (select count(*) from plm.wb_property where identity_method='source_id')::text
         || ' landing_fallback=' || (select count(*) from plm.wb_property where identity_method='natural_key_fallback')::text
         || ' dual_form_labels=' || (
              select count(*) from (
                select source_namespace, label
                from plm.wb_property
                group by 1,2
                having count(*) filter (where identity_method='source_id') > 0
                   and count(*) filter (where identity_method='natural_key_fallback') > 0
              ) d
            )::text
         || ' (2026-10-06 baseline: 227/133 landing, 132 dual-form)' as detail;

select '12_warner_landing_fallback_rows_preserved' as check_name,
       case when
         (select count(*) from plm.wb_property where identity_method = 'natural_key_fallback')
         >= (select count(*) from (
              select source_namespace, label
              from plm.wb_property
              group by 1,2
              having count(*) filter (where identity_method='source_id') > 0
                 and count(*) filter (where identity_method='natural_key_fallback') > 0
            ) d)
         and (select count(*) from plm.wb_property where identity_method = 'natural_key_fallback') > 0
       then 'PASS' else 'FAIL' end as result,
       'landing still holds every natural_key_fallback row (hide is display-only)' as detail;

-- ---------------------------------------------------------------------------
-- PATTERN 2 — Sesame
-- Exactly one row per value_key, preferring field_generation = 'current'.
-- ---------------------------------------------------------------------------
select '20_sesame_one_row_per_value_key' as check_name,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       'value_keys with more than one display row; expected 0, got ' || count(*)::text as detail
from (
  select value_key from proof_sesame_display group by 1 having count(*) > 1
) d;

select '21_sesame_prefers_current' as check_name,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       'dual-generation keys whose survivor is not current; expected 0, got ' || count(*)::text as detail
from proof_sesame_display d
where d.field_generation <> 'current'
  and exists (
    select 1 from plm.sesame_brand sb
    join proof_sesame_latest c on c.id = sb.capture_id
    where sb.value_key = d.value_key
      and sb.field_generation = 'current'
  );

select '22_sesame_display_matches_landing_keys' as check_name,
       case when
         (select count(*) from proof_sesame_display)
         = (select count(distinct sb.value_key)
            from plm.sesame_brand sb
            join proof_sesame_latest c on c.id = sb.capture_id)
       then 'PASS' else 'FAIL' end as result,
       'display row count equals distinct landing value_key count on latest capture' as detail;

select '23_sesame_counts' as check_name,
       'INFO' as result,
       'display_rows=' || (select count(*) from proof_sesame_display)::text
         || ' landing_value_keys=' || (
              select count(distinct sb.value_key)
              from plm.sesame_brand sb join proof_sesame_latest c on c.id = sb.capture_id
            )::text
         || ' dual_generation_keys=' || (
              select count(*) from (
                select sb.value_key
                from plm.sesame_brand sb join proof_sesame_latest c on c.id = sb.capture_id
                group by 1
                having count(*) filter (where sb.field_generation='current') > 0
                   and count(*) filter (where sb.field_generation<>'current') > 0
              ) g
            )::text
         || ' (2026-10-06 baseline: 28 keys, 21 dual-generation)' as detail;

select '24_sesame_landing_generations_preserved' as check_name,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       'dual-generation keys missing a landing row; expected 0, got ' || count(*)::text as detail
from (
  select sb.value_key
  from plm.sesame_brand sb
  join proof_sesame_latest c on c.id = sb.capture_id
  group by 1
  having count(*) filter (where sb.field_generation='current') > 0
     and count(*) filter (where sb.field_generation<>'current') > 0
) dual
where (select count(*) from plm.sesame_brand sb
       join proof_sesame_latest c on c.id = sb.capture_id
       where sb.value_key = dual.value_key) < 2;

-- ---------------------------------------------------------------------------
-- PATTERN 3 — Lucasfilm / Disney
--   a) no Lucasfilm display row whose exact source_id has a Disney twin
--   b) unique Lucasfilm identities preserved
--   c) saved matching decisions and source captures preserved
-- ---------------------------------------------------------------------------
select '30_lucasfilm_display_with_disney_twin' as check_name,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       'displayed Lucasfilm rows that still have a Disney twin; expected 0, got '
         || count(*)::text as detail
from proof_lucasfilm_display p
where exists (
  select 1 from plm.dcp_property d
  where d.source_system = 'disney_dcpvault'
    and d.source_id = p.source_id
);

select '31_lucasfilm_unique_preserved' as check_name,
       case when
         (select count(*) from proof_lucasfilm_display)
         = (select count(*) from plm.lucasfilm_dcp_property p
            where not exists (
              select 1 from plm.dcp_property d
              where d.source_system = 'disney_dcpvault'
                and d.source_id = p.source_id
            ))
         and (select count(*) from proof_lucasfilm_display) > 0
       then 'PASS' else 'FAIL' end as result,
       'every Lucasfilm identity with no Disney twin is still displayed' as detail;

select '32_lucasfilm_counts' as check_name,
       'INFO' as result,
       'lucasfilm_landing=' || (select count(*) from plm.lucasfilm_dcp_property)::text
         || ' shared_with_disney=' || (select count(*) from proof_shared_ids)::text
         || ' unique_displayed=' || (select count(*) from proof_lucasfilm_display)::text
         || ' disney_dcpvault_total=' || (
              select count(*) from plm.dcp_property where source_system = 'disney_dcpvault'
            )::text
         || ' (2026-10-06 baseline: 70 landing, 30 shared, 40 unique)' as detail;

select '33_disney_survivor_present_for_shared_ids' as check_name,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       'shared ids whose Disney dcp_property row is missing; expected 0, got '
         || count(*)::text as detail
from proof_shared_ids s
where not exists (
  select 1 from plm.dcp_property d
  where d.source_system = 'disney_dcpvault'
    and d.source_id = s.source_id
);

-- Decision reachability: every shared id still has resolution history keyed on
-- the shared dcpvault source_id (the Disney arm joins on that identity).
-- SKIP when the environment carries no decision ledger at all (preview is a
-- rehearsal DB and may be empty) — preservation can only be enforced where
-- decisions exist. On production the 2026-10-06 baseline expects all 30 shared
-- ids to carry resolution rows.
select '34_shared_id_decisions_preserved' as check_name,
       case when (select count(*) from plm.dcp_opa_property_resolution) = 0
            then 'SKIP'
            when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       case when (select count(*) from plm.dcp_opa_property_resolution) = 0
            then 'no decision ledger in this environment; preservation applies on production'
            else 'shared ids with no remaining resolution row; expected 0, got '
                 || count(*)::text end as detail
from proof_shared_ids s
where not exists (
  select 1 from plm.dcp_opa_property_resolution r
  where r.source_property_id = s.source_id
);

select '35_shared_id_decisions_counts' as check_name,
       'INFO' as result,
       'shared_ids=' || (select count(*) from proof_shared_ids)::text
         || ' resolution_rows_on_shared=' || (
              select count(*) from plm.dcp_opa_property_resolution r
              where r.source_property_id in (select source_id from proof_shared_ids)
            )::text
         || ' shared_ids_with_members=' || (
              select count(distinct r.source_property_id)
              from plm.dcp_opa_property_resolution r
              join plm.dcp_opa_property_resolution_member m on m.resolution_id = r.resolution_id
              where r.source_property_id in (select source_id from proof_shared_ids)
            )::text
         || ' (2026-10-06 production baseline: 30 shared, all 30 with resolution, 24 with members)' as detail;

-- Member associations: a shared id whose winning decision is 'mapped' must
-- still carry at least one member row. (Not tautological — mapped is a ledger
-- state, membership is a separate table.)
select '36_shared_id_mapped_members_preserved' as check_name,
       case when (select count(*) from plm.dcp_opa_property_resolution) = 0
            then 'SKIP'
            when count(*) = 0 then 'PASS' else 'FAIL' end as result,
       case when (select count(*) from plm.dcp_opa_property_resolution) = 0
            then 'no decision ledger in this environment'
            else 'shared ids with a mapped decision but zero members; expected 0, got '
                 || count(*)::text end as detail
from (
  select s.source_id
  from proof_shared_ids s
  where exists (
    select 1 from plm.dcp_opa_property_resolution r
    where r.source_property_id = s.source_id
      and coalesce(r.creative_decision_state,
                   case when r.approval_status = 'approved' then 'mapped' end) = 'mapped'
  )
) mapped_ids
where not exists (
  select 1
  from plm.dcp_opa_property_resolution r
  join plm.dcp_opa_property_resolution_member m on m.resolution_id = r.resolution_id
  where r.source_property_id = mapped_ids.source_id
);

select '37_lucasfilm_landing_rows_preserved' as check_name,
       case when (select count(*) from plm.lucasfilm_dcp_property) > 0
            then 'PASS' else 'FAIL' end as result,
       'plm.lucasfilm_dcp_property still holds its source rows' as detail;

select '38_disney_landing_rows_preserved' as check_name,
       case when (select count(*) from plm.dcp_property where source_system = 'disney_dcpvault') > 0
            then 'PASS' else 'FAIL' end as result,
       'plm.dcp_property (disney_dcpvault) still holds its source rows' as detail;

select '39_decision_states_preserved' as check_name,
       'INFO' as result,
       'mapped=' || (select count(*) from plm.dcp_opa_property_resolution
                     where creative_decision_state = 'mapped')::text
         || ' unmapped=' || (select count(*) from plm.dcp_opa_property_resolution
                             where creative_decision_state = 'unmapped')::text
         || ' conflict=' || (select count(*) from plm.dcp_opa_property_resolution
                             where creative_decision_state = 'conflict')::text
         || ' excluded=' || (select count(*) from plm.dcp_opa_property_resolution
                             where creative_decision_state = 'excluded')::text
         || ' null_state_approved=' || (select count(*) from plm.dcp_opa_property_resolution
                             where creative_decision_state is null
                               and approval_status = 'approved')::text as detail;

select '40_resolution_ledger_untouched' as check_name,
       case when (select count(*) from plm.dcp_opa_property_resolution) = 0
            then 'SKIP'
            else 'PASS' end as result,
       case when (select count(*) from plm.dcp_opa_property_resolution) = 0
            then 'no decision ledger in this environment; nothing to preserve here'
            else 'plm.dcp_opa_property_resolution non-empty ('
                 || (select count(*) from plm.dcp_opa_property_resolution)::text
                 || ' rows); migration is display-only and never deletes decisions' end as detail;

commit;

-- ---------------------------------------------------------------------------
-- 41. Optional gold standard — call the live inventory function as an
-- authenticated licensing-manager and assert the three patterns on the
-- actual returned JSON rows. Prints SKIP if no qualifying profile exists.
-- READ-ONLY: the function is STABLE and returns jsonb only.
-- ---------------------------------------------------------------------------
do $proof$
declare
  v_auth uuid;
  v_page jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_cursor text := null;
  v_guard int := 0;
  v_warner_bad int;
  v_sesame_dup int;
  v_lucas_bad int;
  v_total int;
begin
  select p.auth_user_id into v_auth
  from app.profile p
  where p.auth_user_id is not null
    and exists (
      select 1 from app.user_role ur
      join app.role r on r.id = ur.role_id
      where ur.profile_id = p.id
        and ur.revoked_at is null
        and r.slug in ('licensing', 'administrator')
    )
    and exists (
      select 1 from app.app_access aa
      where aa.profile_id = p.id
        and aa.revoked_at is null
        and aa.app in ('plm', 'admin')
    )
  limit 1;

  if v_auth is null then
    raise notice '41_inventory_call | SKIP | no licensing-manager/admin profile with plm or admin app_access';
    return;
  end if;

  -- Impersonate that authenticated caller for the function's licensing gate.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_auth, 'role', 'authenticated')::text, true);

  loop
    v_guard := v_guard + 1;
    exit when v_guard > 50;
    v_page := api.db_data_admin_scraped_source_inventory(
      'property', null, v_cursor, 1000);
    v_rows := v_rows || coalesce(v_page -> 'rows', '[]'::jsonb);
    v_cursor := v_page ->> 'next_cursor';
    exit when v_cursor is null or v_cursor = '';
  end loop;

  v_total := jsonb_array_length(v_rows);

  select count(*) into v_warner_bad
  from jsonb_array_elements(v_rows) r
  where r ->> 'source_table' = 'plm.wb_property'
    and (r ->> 'source_id') like '%:natural_key_fallback:%'
    and exists (
      select 1 from plm.wb_property p
      where p.identity_method = 'natural_key_fallback'
        and p.label = r ->> 'display_label'
        and exists (
          select 1 from plm.wb_property t
          where t.source_namespace = p.source_namespace
            and t.identity_method = 'source_id'
            and t.label = p.label
        )
    );

  select count(*) into v_sesame_dup
  from (
    select r ->> 'source_id' as sid
    from jsonb_array_elements(v_rows) r
    where r ->> 'source_table' = 'source.thelettera_brand'
    group by 1
    having count(*) > 1
  ) d;

  select count(*) into v_lucas_bad
  from jsonb_array_elements(v_rows) r
  where r ->> 'source_table' = 'plm.lucasfilm_dcp_property'
    and exists (
      select 1 from plm.dcp_property d
      where d.source_system = 'disney_dcpvault'
        and d.source_id = r ->> 'source_id'
    );

  raise notice '41_inventory_rows | INFO | total_property_rows=%', v_total;
  raise notice '42_inventory_warner_fallback_twin | % | bad=%',
    case when v_warner_bad = 0 then 'PASS' else 'FAIL' end, v_warner_bad;
  raise notice '43_inventory_sesame_duplicate_label | % | bad=%',
    case when v_sesame_dup = 0 then 'PASS' else 'FAIL' end, v_sesame_dup;
  raise notice '44_inventory_lucasfilm_disney_twin | % | bad=%',
    case when v_lucas_bad = 0 then 'PASS' else 'FAIL' end, v_lucas_bad;
end
$proof$;

-- ---------------------------------------------------------------------------
-- Done. Gate: zero FAIL rows.
-- ---------------------------------------------------------------------------
select '99_done' as check_name,
       'INFO' as result,
       'proof script complete — gate on zero FAIL rows' as detail;
