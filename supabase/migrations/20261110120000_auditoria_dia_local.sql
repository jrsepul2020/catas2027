-- Auditoría del día cargado en LOCAL (App 2). Solo informa; nunca bloquea.
-- Aditivo: columna puntos_activos + RPC auditoria_dia_local.

alter table public.catadores
  add column if not exists puntos_activos boolean not null default true;

-- Suma de criterios numéricos de una ficha (ignora metadatos).
create or replace function public.suma_criterios(s jsonb)
returns numeric
language sql
immutable
set search_path = public
as $$
  select coalesce(sum((v #>> '{}')::numeric), 0)
  from jsonb_each(coalesce(s, '{}'::jsonb)) as e(k, v)
  where jsonb_typeof(v) = 'number'
    and k not in ('total', 'manual', 'excluido', 'desactivado', 'cuenta', 'cuenta_en_media');
$$;

revoke all on function public.suma_criterios(jsonb) from public;
grant execute on function public.suma_criterios(jsonb) to authenticated, anon, service_role;

-- Devuelve hallazgos del día LOCAL: [{grupo, texto}, ...]
-- grupo = 'mirar' (hay que mirarlo) | 'cuenta' (para tener en cuenta)
create or replace function public.auditoria_dia_local()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_out jsonb := '[]'::jsonb;
  v_esperadas integer := 5;
begin
  select coalesce(catadores_por_mesa, 5) into v_esperadas
  from public.concursos
  order by id
  limit 1;
  if v_esperadas is null or v_esperadas < 1 then
    v_esperadas := 5;
  end if;

  -- 1) Completada/finalizada con 0 notas o menos de las esperadas
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'mirar',
      'codigo', 'pocas_notas',
      'texto', format(
        'La muestra %s de la tanda %s (%s) está %s y tiene %s nota%s (se esperan %s).',
        coalesce(m.codigo_ciego::text, '?'),
        coalesce(t.numero::text, '?'),
        coalesce(me.nombre, 'Mesa ?'),
        tm.estado,
        n.n,
        case when n.n = 1 then '' else 's' end,
        v_esperadas
      )
    ) order by me.numero nulls last, t.numero, m.codigo_ciego)
    from public.tanda_muestras tm
    join public.tandas t on t.id = tm.tanda_id
    left join public.mesas me on me.id = t.mesa_id
    join public.muestras m on m.id = tm.muestra_id
    cross join lateral (
      select count(*)::int as n
      from public.puntuaciones p
      where p.muestra_id = tm.muestra_id
        and (p.tanda_id = tm.tanda_id or p.tanda_id is null)
    ) n
    where tm.estado in ('completada', 'finalizada')
      and n.n < v_esperadas
  ), '[]'::jsonb);

  -- 2) Pendiente con alguna nota
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'mirar',
      'codigo', 'pendiente_con_notas',
      'texto', format(
        'La muestra %s de la tanda %s (%s) sigue pendiente pero ya tiene %s nota%s.',
        coalesce(m.codigo_ciego::text, '?'),
        coalesce(t.numero::text, '?'),
        coalesce(me.nombre, 'Mesa ?'),
        n.n,
        case when n.n = 1 then '' else 's' end
      )
    ) order by me.numero nulls last, t.numero, m.codigo_ciego)
    from public.tanda_muestras tm
    join public.tandas t on t.id = tm.tanda_id
    left join public.mesas me on me.id = t.mesa_id
    join public.muestras m on m.id = tm.muestra_id
    cross join lateral (
      select count(*)::int as n
      from public.puntuaciones p
      where p.muestra_id = tm.muestra_id
        and (p.tanda_id = tm.tanda_id or p.tanda_id is null)
    ) n
    where tm.estado = 'pendiente'
      and n.n > 0
  ), '[]'::jsonb);

  -- 3) Muestras del día sin tanda
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'mirar',
      'codigo', 'sin_tanda',
      'texto', format(
        'La muestra %s no está en ninguna tanda: no se cataría.',
        coalesce(m.codigo_ciego::text, '?')
      )
    ) order by m.codigo_ciego)
    from public.muestras m
    where not exists (
      select 1 from public.tanda_muestras tm where tm.muestra_id = m.id
    )
  ), '[]'::jsonb);

  -- 4) Dos o más dispositivos → mismo catador
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'mirar',
      'codigo', 'tablets_duplicadas',
      'texto', format(
        'El catador %s tiene %s tablets apuntándole: %s.',
        coalesce(c.nombre, 'sin nombre'),
        d.n,
        d.tablets
      )
    ) order by c.nombre)
    from (
      select catador_id,
             count(*)::int as n,
             string_agg(id::text, ', ' order by id) as tablets
      from public.dispositivos
      where catador_id is not null
      group by catador_id
      having count(*) > 1
    ) d
    join public.catadores c on c.id = d.catador_id
  ), '[]'::jsonb);

  -- 5) Catadores con puntos desactivados (recordatorio)
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'cuenta',
      'codigo', 'puntos_desactivados',
      'texto', format(
        'Catador %s (%s): puntos desactivados, no cuentan en la media.',
        coalesce(c.nombre, 'sin nombre'),
        coalesce(me.nombre, case when c.mesa is not null then 'Mesa ' || c.mesa else 'sin mesa' end)
      )
    ) order by me.numero nulls last, c.nombre)
    from public.catadores c
    left join public.mesas me on me.id = c.mesa_id
    where coalesce(c.puntos_activos, true) = false
       or exists (
         select 1
         from public.puntuaciones p
         where p.catador_id = c.id
           and (
             (p.scores ? 'excluido' and coalesce((p.scores->>'excluido')::boolean, false))
             or (p.scores ? 'desactivado' and coalesce((p.scores->>'desactivado')::boolean, false))
             or (p.scores ? 'cuenta' and not coalesce((p.scores->>'cuenta')::boolean, true))
             or (p.scores ? 'cuenta_en_media' and not coalesce((p.scores->>'cuenta_en_media')::boolean, true))
           )
       )
  ), '[]'::jsonb);

  -- 6) Notas de catador que no es de la mesa de la tanda
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'mirar',
      'codigo', 'nota_fuera_mesa',
      'texto', format(
        'Nota de %s en la muestra %s (tanda %s, %s): el catador está en %s, no en esa mesa.',
        coalesce(c.nombre, 'sin nombre'),
        coalesce(m.codigo_ciego::text, '?'),
        coalesce(t.numero::text, '?'),
        coalesce(me_t.nombre, 'Mesa ?'),
        coalesce(me_c.nombre, case when c.mesa is not null then 'Mesa ' || c.mesa else 'sin mesa' end)
      )
    ) order by me_t.numero nulls last, t.numero, m.codigo_ciego, c.nombre)
    from public.puntuaciones p
    join public.tandas t on t.id = p.tanda_id
    join public.catadores c on c.id = p.catador_id
    join public.muestras m on m.id = p.muestra_id
    left join public.mesas me_t on me_t.id = t.mesa_id
    left join public.mesas me_c on me_c.id = c.mesa_id
    where t.mesa_id is not null
      and (c.mesa_id is distinct from t.mesa_id)
  ), '[]'::jsonb);

  -- 7) Total ≠ suma de criterios
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'mirar',
      'codigo', 'total_descuadrado',
      'texto', format(
        'Nota de %s en muestra %s: total guardado %s, suma de criterios %s.',
        coalesce(c.nombre, 'sin nombre'),
        coalesce(m.codigo_ciego::text, '?'),
        trim(to_char(p.total, 'FM999990.######')),
        trim(to_char(public.suma_criterios(p.scores), 'FM999990.######'))
      )
    ) order by m.codigo_ciego, c.nombre)
    from public.puntuaciones p
    join public.catadores c on c.id = p.catador_id
    join public.muestras m on m.id = p.muestra_id
    where jsonb_typeof(p.scores) = 'object'
      and exists (
        select 1
        from jsonb_each(p.scores) e(k, v)
        where jsonb_typeof(v) = 'number'
          and k not in ('total', 'manual', 'excluido', 'desactivado', 'cuenta', 'cuenta_en_media')
      )
      and abs(p.total - public.suma_criterios(p.scores)) > 0.05
  ), '[]'::jsonb);

  -- 8) Incidencias abiertas
  v_out := v_out || coalesce((
    select jsonb_agg(jsonb_build_object(
      'grupo', 'cuenta',
      'codigo', 'incidencia_abierta',
      'texto', format(
        'Incidencia abierta: muestra %s, tanda %s (%s). Motivo: %s. Desde %s.',
        coalesce(m.codigo_ciego::text, '?'),
        coalesce(t.numero::text, '?'),
        coalesce(me.nombre, 'Mesa ?'),
        coalesce(nullif(trim(tm.incidencia_motivo), ''), 'sin motivo'),
        to_char(timezone('Europe/Madrid', coalesce(tm.updated_at, now())), 'DD/MM HH24:MI')
      )
    ) order by tm.updated_at nulls last, m.codigo_ciego)
    from public.tanda_muestras tm
    join public.tandas t on t.id = tm.tanda_id
    left join public.mesas me on me.id = t.mesa_id
    join public.muestras m on m.id = tm.muestra_id
    where tm.estado = 'incidencia'
  ), '[]'::jsonb);

  return v_out;
end;
$$;

revoke all on function public.auditoria_dia_local() from public;
grant execute on function public.auditoria_dia_local() to authenticated, service_role;
-- LOCAL de sede a veces opera sin sesión de gestión; permitir lectura de avisos.
grant execute on function public.auditoria_dia_local() to anon;
