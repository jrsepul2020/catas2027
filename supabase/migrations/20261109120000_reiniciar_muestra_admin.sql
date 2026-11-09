-- Admin: borrar notas de una muestra de tanda y dejarla en pendiente (desde activa/completada/incidencia).

create or replace function public.reiniciar_muestra_admin(p_tm integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.tanda_muestras;
  v_n integer := 0;
begin
  if auth.uid() is null then
    raise exception 'SOLO_AUTH: hace falta sesión de gestión';
  end if;

  select * into r from public.tanda_muestras where id = p_tm for update;
  if r.id is null then
    raise exception 'Muestra de tanda no encontrada';
  end if;

  perform set_config('virtus.reabrir', 'on', true);

  delete from public.puntuaciones
   where tanda_id = r.tanda_id
     and muestra_id = r.muestra_id;
  get diagnostics v_n = row_count;

  update public.tanda_muestras
     set estado = 'pendiente',
         incidencia_motivo = null
   where id = p_tm;

  insert into public.registro_cambios (dia_id, accion, tabla, registro_id, antes, motivo)
  values (
    public._dia_de_tanda(r.tanda_id),
    'reiniciar_muestra',
    'tanda_muestras',
    p_tm::text,
    to_jsonb(r),
    format('Admin reinició muestra: borró %s notas y pasó a pendiente', v_n)
  );

  return v_n;
end;
$$;

revoke execute on function public.reiniciar_muestra_admin(integer) from public, anon;
grant execute on function public.reiniciar_muestra_admin(integer) to authenticated;
