-- Datos DEMO: borrar concurso completo + crear un día listo para sincronizar.
-- Solo authenticated. La clave «0000» se comprueba en la app (no aquí).

-- ---------- Borrar todo el concurso (CLOUD o LOCAL) ----------
create or replace function public.demo_borrar_todo()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_concursos integer;
begin
  perform set_config('virtus.reabrir', 'on', true);
  perform set_config('virtus.sync', 'on', true);

  select count(*)::int into v_concursos from public.concursos;

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

  -- Tablets físicas se conservan (solo se desvinculan arriba).
  if to_regclass('public.sync_borrados') is not null then
    execute 'truncate table public.sync_borrados restart identity';
  end if;

  if to_regclass('public.sync_estado') is not null then
    update public.sync_estado set
      dia_id = null,
      estado = 'vacio',
      snapshot_puestos = null,
      cuadre_ok = false,
      actualizado_en = now()
    where id = 1;
  end if;

  return jsonb_build_object('ok', true, 'concursos_antes', v_concursos);
end $$;

revoke execute on function public.demo_borrar_todo() from public, anon;
grant execute on function public.demo_borrar_todo() to authenticated;

-- ---------- Crear día DEMO completo en CLOUD ----------
-- 5 mesas · 25 catadores · 5 presidentes · 6 tandas × 22 muestras
create or replace function public.demo_crear_dia_completo()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_concurso integer;
  v_categoria integer;
  v_dia integer;
  v_mesas integer[] := '{}';
  v_cats integer[] := '{}';
  v_muestras integer[] := '{}';
  v_tanda integer;
  v_mesa integer;
  v_cat integer;
  v_i integer;
  v_j integer;
  v_ord integer;
  v_cod text;
  v_ficha jsonb := jsonb_build_object(
    'criterios', jsonb_build_array(
      jsonb_build_object('clave', 'aspecto', 'nombre', 'Aspecto', 'max', 5),
      jsonb_build_object('clave', 'aroma', 'nombre', 'Aroma', 'max', 30),
      jsonb_build_object('clave', 'sabor', 'nombre', 'Sabor', 'max', 50),
      jsonb_build_object('clave', 'armonia', 'nombre', 'Armonía', 'max', 15)
    )
  );
begin
  if exists (select 1 from public.concursos) then
    raise exception 'Hay datos de concurso. Usa «Borrar todo» (clave 0000) antes de crear el DEMO.';
  end if;

  insert into public.concursos (nombre, fecha_inicio, fecha_fin, gran_oro, oro, plata, catadores_por_mesa, activo)
  values ('Virtus Demo 2027', current_date, current_date + 2, 93, 89, 85, 5, true)
  returning id into v_concurso;

  insert into public.categorias (codigo, nombre, ficha)
  values ('vt', 'Vinos Tranquilos', v_ficha)
  returning id into v_categoria;

  insert into public.dias_concurso (concurso_id, fecha, nombre)
  values (v_concurso, current_date, 'Día Demo')
  returning id into v_dia;

  for v_i in 1..5 loop
    insert into public.mesas (concurso_id, numero, nombre)
    values (v_concurso, v_i, 'Mesa ' || v_i)
    returning id into v_mesa;
    v_mesas := array_append(v_mesas, v_mesa);
  end loop;

  for v_i in 1..25 loop
    insert into public.catadores (nombre, rol, activo, presente, pais_codigo, titulo)
    values (
      'Catador Demo ' || lpad(v_i::text, 2, '0'),
      'catador',
      false,
      true,
      'ES',
      case when v_i % 5 = 1 then 'Presidente' else 'Catador' end
    )
    returning id into v_cat;
    v_cats := array_append(v_cats, v_cat);
  end loop;

  -- Asignaciones: 5 por mesa, puesto 1 = presidente
  for v_i in 1..5 loop
    for v_j in 1..5 loop
      insert into public.asignaciones (dia_id, catador_id, mesa_id, puesto, rol)
      values (
        v_dia,
        v_cats[(v_i - 1) * 5 + v_j],
        v_mesas[v_i],
        v_j,
        case when v_j = 1 then 'presidente' else 'catador' end
      );
    end loop;
  end loop;

  -- 132 muestras (códigos ≥ 1000 para que puedan premiar)
  for v_i in 1..132 loop
    v_cod := (2000 + v_i)::text;
    insert into public.muestras (concurso_id, categoria_id, codigo_ciego, codigo_texto, activo)
    values (v_concurso, v_categoria, v_cod, 'REF-' || v_cod, true)
    returning id into v_cat;
    v_muestras := array_append(v_muestras, v_cat);
  end loop;

  -- 6 tandas × 22 muestras (reparto: mesas 1..5 + extra en mesa 1)
  for v_i in 1..6 loop
    v_mesa := v_mesas[case when v_i = 6 then 1 else v_i end];
    insert into public.tandas (mesa_id, numero, estado, categoria_id, dia_id, orden)
    values (v_mesa, 900 + v_i, 'pendiente', v_categoria, v_dia, v_i - 1)
    returning id into v_tanda;

    for v_j in 1..22 loop
      v_ord := (v_i - 1) * 22 + v_j;
      insert into public.tanda_muestras (tanda_id, muestra_id, orden, estado)
      values (v_tanda, v_muestras[v_ord], v_j, 'pendiente');
    end loop;
  end loop;

  insert into public.registro_cambios (accion, tabla, registro_id, motivo, dia_id)
  values ('demo_crear_dia', 'dias_concurso', v_dia::text, 'Datos DEMO generados', v_dia);

  return jsonb_build_object(
    'ok', true,
    'concurso_id', v_concurso,
    'dia_id', v_dia,
    'mesas', 5,
    'catadores', 25,
    'presidentes', 5,
    'tandas', 6,
    'muestras', 132
  );
end $$;

revoke execute on function public.demo_crear_dia_completo() from public, anon;
grant execute on function public.demo_crear_dia_completo() to authenticated;
