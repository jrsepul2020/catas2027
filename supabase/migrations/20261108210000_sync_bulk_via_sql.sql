-- Updates/deletes masivos solo dentro de SQL (PostgREST bloquea UPDATE/DELETE
-- sin filtro vía API REST). Corrige el generador y añade RPCs para tablets.

-- ---------- Generador: limpiar puestos de catadores CON where explícito ----------
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
  v_intentos integer;
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

  if cardinality(v_mesas) is null or cardinality(v_mesas) = 0 then
    raise exception 'No hay mesas en el concurso';
  end if;
  if cardinality(v_cats) is null or cardinality(v_cats) < cardinality(v_mesas) then
    raise exception 'Hacen falta al menos % catadores (uno por mesa)', cardinality(v_mesas);
  end if;

  select count(*)::int into v_dia_ord
  from public.dias_concurso d
  where d.concurso_id = v_concurso
    and (d.fecha, d.id) < (select fecha, id from public.dias_concurso where id = p_dia_id);

  delete from public.asignaciones where dia_id = p_dia_id;

  for v_mesa in select unnest(v_mesas) loop
    for v_puesto in 1..v_por_mesa loop
      v_intentos := 0;
      v_cat := v_cats[1 + ((v_i + v_dia_ord * v_por_mesa) % cardinality(v_cats))];
      while exists (
        select 1 from public.asignaciones where dia_id = p_dia_id and catador_id = v_cat
      ) loop
        v_i := v_i + 1;
        v_intentos := v_intentos + 1;
        v_cat := v_cats[1 + ((v_i + v_dia_ord * v_por_mesa) % cardinality(v_cats))];
        if v_intentos > cardinality(v_cats) then
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

  -- Cloud: catadores = solo persona (ignorar mesa/puesto/rol). WHERE obligatorio.
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

-- ---------- Vaciar LOCAL: updates con where explícito ----------
create or replace function public.sync_vaciar_local()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
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

-- ---------- Recalcular todas las tablets tras bajar un día ----------
-- p_vinculos: [{"tablet":1,"catador_id":12}, ...]
-- tablet = (nº mesa − 1) × 5 + puesto
create or replace function public.sync_recalcular_dispositivos(p_vinculos jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
  v_tablet integer;
  v_cat integer;
  v_n integer := 0;
begin
  update public.dispositivos set catador_id = null where id is not null;
  update public.catadores set activo = false where id is not null;

  for v in select * from jsonb_array_elements(coalesce(p_vinculos, '[]'::jsonb)) loop
    v_tablet := (v->>'tablet')::int;
    v_cat := (v->>'catador_id')::int;
    if v_tablet is null or v_cat is null then
      continue;
    end if;

    insert into public.dispositivos (id, device_id, catador_id, ultima_vez)
    values (
      v_tablet,
      'tablet-' || lpad(v_tablet::text, 2, '0'),
      v_cat,
      now()
    )
    on conflict (id) do update
      set catador_id = excluded.catador_id,
          ultima_vez = now();

    v_n := v_n + 1;
  end loop;

  return v_n;
end $$;

revoke execute on function public.sync_recalcular_dispositivos(jsonb) from public, anon;
grant execute on function public.sync_recalcular_dispositivos(jsonb) to authenticated;

-- ---------- Cambios de última hora: solo los asientos indicados ----------
-- p_asientos: [{"tablet":3,"catador_id":null|12}, ...]
create or replace function public.sync_aplicar_asientos(p_asientos jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
  v_tablet integer;
  v_cat integer;
begin
  for v in select * from jsonb_array_elements(coalesce(p_asientos, '[]'::jsonb)) loop
    v_tablet := (v->>'tablet')::int;
    if v_tablet is null then
      continue;
    end if;
    v_cat := nullif(v->>'catador_id', '')::int;

    insert into public.dispositivos (id, device_id, catador_id, ultima_vez)
    values (
      v_tablet,
      'tablet-' || lpad(v_tablet::text, 2, '0'),
      null,
      now()
    )
    on conflict (id) do nothing;

    -- Liberar otras tablets que apuntaran a este catador
    if v_cat is not null then
      update public.dispositivos
         set catador_id = null
       where catador_id = v_cat
         and id is distinct from v_tablet;
    end if;

    update public.dispositivos
       set catador_id = v_cat,
           ultima_vez = now()
     where id = v_tablet;
  end loop;
end $$;

revoke execute on function public.sync_aplicar_asientos(jsonb) from public, anon;
grant execute on function public.sync_aplicar_asientos(jsonb) to authenticated;
