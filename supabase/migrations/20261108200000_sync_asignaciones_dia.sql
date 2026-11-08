-- Sync por día con asignaciones (CLOUD) → catadores aplanados (LOCAL).
-- Aditivo e idempotente. No borra columnas de catadores (las tablets / LOCAL las usan).

-- ---------- asignaciones: marcas y unicidad ----------
alter table public.asignaciones add column if not exists updated_at timestamptz not null default now();

create unique index if not exists uq_asignaciones_dia_catador
  on public.asignaciones (dia_id, catador_id);
create unique index if not exists uq_asignaciones_dia_mesa_puesto
  on public.asignaciones (dia_id, mesa_id, puesto);

drop trigger if exists tg_sync_touch_asignaciones on public.asignaciones;
do $$ begin
  if exists (select 1 from pg_proc where proname = 'tg_sync_touch') then
    create trigger tg_sync_touch_asignaciones
      before update on public.asignaciones
      for each row execute function public.tg_sync_touch();
  end if;
end $$;

-- LOCAL guarda dia_id del día bajado sin necesitar la fila en dias_concurso
alter table public.sync_estado drop constraint if exists sync_estado_dia_id_fkey;

-- Snapshot de puestos tras la última bajada (para avisar cambios locales)
alter table public.sync_estado add column if not exists snapshot_puestos jsonb;
alter table public.sync_estado add column if not exists cuadre_ok boolean not null default false;
alter table public.sync_estado add column if not exists ultima_bajada timestamptz;
alter table public.sync_estado add column if not exists ultima_subida timestamptz;

-- ---------- Vaciar datos de concurso en LOCAL (deja sync_estado y dispositivos físicos) ----------
create or replace function public.sync_vaciar_local()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Notas aprobadas: permitir borrado durante vaciado
  perform set_config('virtus.reabrir', 'on', true);
  perform set_config('virtus.sync', 'on', true);

  update public.dispositivos set catador_id = null where id is not null;
  update public.catadores
     set activo = false, mesa_id = null, mesa = null, puesto = null, rol = 'catador'
   where id is not null;

  truncate table
    public.puntuaciones,
    public.tanda_muestras,
    public.tandas,
    public.medallas,
    public.asignaciones,
    public.registro_cambios,
    public.muestras,
    public.catadores,
    public.mesas,
    public.dias_concurso,
    public.categorias,
    public.concursos
    restart identity cascade;

  -- Dispositivos se conservan (tablets físicas); solo desvinculados
  update public.sync_estado set
    dia_id = null,
    estado = 'vacio',
    snapshot_puestos = null,
    cuadre_ok = false,
    actualizado_en = now()
  where id = 1;
end $$;

revoke execute on function public.sync_vaciar_local() from public, anon;
grant execute on function public.sync_vaciar_local() to authenticated;

-- ---------- Generador de asignaciones de prueba (CLOUD) ----------
-- No toca mesa/puesto/rol en catadores. Puesto 1 = presidente.
create or replace function public.generar_asignaciones_prueba(p_dia_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_concurso integer;
  v_dia_ord integer;
  v_mesas integer[];
  v_cats integer[];
  v_mesa integer;
  v_puesto integer;
  v_i integer := 0;
  v_cat integer;
  v_n integer := 0;
  v_por_mesa integer := 5;
begin
  select concurso_id into v_concurso from public.dias_concurso where id = p_dia_id;
  if v_concurso is null then
    raise exception 'Día % no existe', p_dia_id;
  end if;

  select coalesce(catadores_por_mesa, 5) into v_por_mesa
  from public.concursos where id = v_concurso;

  select coalesce(array_agg(id order by numero), '{}') into v_mesas
  from public.mesas where concurso_id = v_concurso;

  select coalesce(array_agg(id order by id), '{}') into v_cats
  from public.catadores;

  if cardinality(v_mesas) = 0 then
    raise exception 'No hay mesas en el concurso';
  end if;
  if cardinality(v_cats) < cardinality(v_mesas) then
    raise exception 'Hacen falta al menos % catadores (uno por mesa)', cardinality(v_mesas);
  end if;

  -- Orden del día dentro del concurso (0,1,2…) para rotar
  select count(*)::int into v_dia_ord
  from public.dias_concurso d
  where d.concurso_id = v_concurso
    and (d.fecha, d.id) < (select fecha, id from public.dias_concurso where id = p_dia_id);

  delete from public.asignaciones where dia_id = p_dia_id;

  for v_mesa in select unnest(v_mesas) loop
    for v_puesto in 1..v_por_mesa loop
      v_cat := v_cats[1 + ((v_i + v_dia_ord * v_por_mesa) % cardinality(v_cats))];
      -- Evitar duplicar catador el mismo día: avanzar hasta libre
      while exists (
        select 1 from public.asignaciones where dia_id = p_dia_id and catador_id = v_cat
      ) loop
        v_i := v_i + 1;
        v_cat := v_cats[1 + ((v_i + v_dia_ord * v_por_mesa) % cardinality(v_cats))];
        if v_i > cardinality(v_cats) * 3 then
          raise exception 'No hay catadores suficientes para cubrir todas las plazas sin repetir';
        end if;
      end loop;

      insert into public.asignaciones (dia_id, catador_id, mesa_id, puesto, rol, tablet_id, updated_at)
      values (
        p_dia_id,
        v_cat,
        v_mesa,
        v_puesto,
        case when v_puesto = 1 then 'presidente' else 'catador' end,
        null,
        now()
      );
      v_n := v_n + 1;
      v_i := v_i + 1;
    end loop;
  end loop;

  -- Asegurar que Cloud no usa mesa/puesto/rol en catadores (WHERE obligatorio).
  -- La versión canónica queda en 20261108210000 (reemplaza esta función).
  update public.catadores
     set mesa_id = null, mesa = null, puesto = null, rol = 'catador'
   where id is not null
     and (
       mesa_id is not null
       or mesa is not null
       or puesto is not null
       or rol is distinct from 'catador'
     );

  return jsonb_build_object('asignaciones', v_n, 'dia_id', p_dia_id, 'mesas', cardinality(v_mesas));
end $$;

revoke execute on function public.generar_asignaciones_prueba(integer) from public, anon;
grant execute on function public.generar_asignaciones_prueba(integer) to authenticated;

-- Upsert de puntuaciones por (catador_id, muestra_id) sin depender de updated_at
-- (la subida Local→Cloud siempre aplica la nota local).
create or replace function public.sync_upsert_puntuaciones(p_filas jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_n integer;
begin
  perform set_config('virtus.sync', 'on', true);
  perform set_config('virtus.reabrir', 'on', true);
  insert into public.puntuaciones (catador_id, muestra_id, tanda_id, scores, total, estado, updated_at)
  select
    (f->>'catador_id')::int,
    (f->>'muestra_id')::int,
    (f->>'tanda_id')::int,
    coalesce(f->'scores', '{}'::jsonb),
    (f->>'total')::numeric,
    coalesce(f->>'estado', 'enviada'),
    coalesce((f->>'updated_at')::timestamptz, now())
  from jsonb_array_elements(p_filas) f
  on conflict (catador_id, muestra_id) do update set
    tanda_id = excluded.tanda_id,
    scores = excluded.scores,
    total = excluded.total,
    estado = excluded.estado,
    updated_at = excluded.updated_at;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

revoke execute on function public.sync_upsert_puntuaciones(jsonb) from public, anon;
grant execute on function public.sync_upsert_puntuaciones(jsonb) to authenticated;
