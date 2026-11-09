-- Admin puede reabrir/editar notas aprobadas; helpers atómicos de asignaciones.

create or replace function public.puntuar_manual_admin(
  p_muestra integer,
  p_catador integer,
  p_tanda integer,
  p_total numeric
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'SOLO_AUTH: hace falta sesión de gestión';
  end if;
  perform set_config('virtus.reabrir', 'on', true);

  -- Si la muestra estaba cerrada, volver a activa para que el admin pueda seguir.
  update public.tanda_muestras
     set estado = 'activa'
   where tanda_id = p_tanda
     and muestra_id = p_muestra
     and estado = 'completada';

  insert into public.puntuaciones (muestra_id, catador_id, tanda_id, total, scores, estado)
  values (
    p_muestra,
    p_catador,
    p_tanda,
    p_total,
    jsonb_build_object('manual', true, 'total', p_total),
    'enviada'
  )
  on conflict (catador_id, muestra_id) do update
    set total = excluded.total,
        scores = excluded.scores,
        estado = 'enviada',
        tanda_id = excluded.tanda_id;

  insert into public.registro_cambios (accion, tabla, registro_id, motivo)
  values (
    'reabrir_nota',
    'puntuaciones',
    p_muestra::text || '|' || p_catador::text,
    'Admin forzó nota manual ' || p_total::text || ' (tanda ' || p_tanda::text || ')'
  );
end;
$$;

create or replace function public.borrar_puntuacion_admin(p_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_muestra integer;
  v_catador integer;
  v_tanda integer;
begin
  if auth.uid() is null then
    raise exception 'SOLO_AUTH: hace falta sesión de gestión';
  end if;
  select muestra_id, catador_id, tanda_id into v_muestra, v_catador, v_tanda
    from public.puntuaciones where id = p_id;
  if v_muestra is null then
    return;
  end if;
  perform set_config('virtus.reabrir', 'on', true);
  delete from public.puntuaciones where id = p_id;
  update public.tanda_muestras
     set estado = 'activa'
   where tanda_id = v_tanda
     and muestra_id = v_muestra
     and estado = 'completada';
  insert into public.registro_cambios (accion, tabla, registro_id, motivo)
  values (
    'reabrir_nota',
    'puntuaciones',
    coalesce(v_muestra::text, '') || '|' || coalesce(v_catador::text, ''),
    'Admin borró nota aprobada/bloqueada'
  );
end;
$$;

create or replace function public.intercambiar_asignaciones(
  p_a integer,
  p_b integer,
  p_dia integer,
  p_motivo text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  aa public.asignaciones%rowtype;
  bb public.asignaciones%rowtype;
begin
  if auth.uid() is null then
    raise exception 'SOLO_AUTH: hace falta sesión de gestión';
  end if;
  select * into aa from public.asignaciones where dia_id = p_dia and catador_id = p_a;
  select * into bb from public.asignaciones where dia_id = p_dia and catador_id = p_b;
  if aa.id is null or bb.id is null then
    raise exception 'SIN_ASIGNACION: falta asignación de uno de los catadores ese día';
  end if;
  -- Aparcar A (NULL no viola uq_asignaciones_dia_mesa_puesto).
  update public.asignaciones set mesa_id = null, puesto = null where id = aa.id;
  update public.asignaciones
     set mesa_id = aa.mesa_id, puesto = aa.puesto, rol = aa.rol
   where id = bb.id;
  update public.asignaciones
     set mesa_id = bb.mesa_id, puesto = bb.puesto, rol = bb.rol
   where id = aa.id;
  insert into public.registro_cambios (accion, tabla, registro_id, motivo, dia_id)
  values ('cambio_puesto', 'asignaciones', p_a::text || ',' || p_b::text, p_motivo, p_dia);
end;
$$;

revoke execute on function public.puntuar_manual_admin(integer, integer, integer, numeric) from public, anon;
revoke execute on function public.borrar_puntuacion_admin(integer) from public, anon;
revoke execute on function public.intercambiar_asignaciones(integer, integer, integer, text) from public, anon;
grant execute on function public.puntuar_manual_admin(integer, integer, integer, numeric) to authenticated;
grant execute on function public.borrar_puntuacion_admin(integer) to authenticated;
grant execute on function public.intercambiar_asignaciones(integer, integer, integer, text) to authenticated;
