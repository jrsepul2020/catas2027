-- =====================================================================
-- Esquema BASE de Catas2027 (copia del proyecto cloud, 2026-11-06).
-- Sirve para recrear la base idéntica en Supabase LOCAL.
-- Es idempotente: en cloud (donde ya existe) no cambia nada.
-- =====================================================================

create sequence if not exists public.concursos_id_seq;
create sequence if not exists public.categorias_id_seq;
create sequence if not exists public.mesas_id_seq;
create sequence if not exists public.catadores_id_seq;
create sequence if not exists public.dispositivos_id_seq;
create sequence if not exists public.muestras_id_seq;
create sequence if not exists public.tandas_id_seq;
create sequence if not exists public.tanda_muestras_id_seq;
create sequence if not exists public.puntuaciones_id_seq;
create sequence if not exists public.medallas_id_seq;
create sequence if not exists public.dias_concurso_id_seq;
create sequence if not exists public.asignaciones_id_seq;
create sequence if not exists public.despertador_tabla_id_seq;

create table if not exists public.concursos (
  id integer default nextval('concursos_id_seq'::regclass) not null,
  nombre text not null,
  fecha_inicio date,
  fecha_fin date,
  gran_oro numeric default 92,
  oro numeric default 85,
  plata numeric default 82,
  catadores_por_mesa integer default 5,
  activo boolean default true,
  logo_url text,
  color_primario text default '#8B0000'::text,
  color_secundario text default '#F5C518'::text,
  imagen_gran_oro text,
  imagen_oro text,
  imagen_plata text,
  patrocinadores jsonb
);

create table if not exists public.categorias (
  id integer default nextval('categorias_id_seq'::regclass) not null,
  codigo text not null,
  nombre text not null,
  ficha jsonb not null
);

create table if not exists public.dias_concurso (
  id integer default nextval('dias_concurso_id_seq'::regclass) not null,
  concurso_id integer not null,
  fecha date not null,
  nombre text
);

create table if not exists public.mesas (
  id integer default nextval('mesas_id_seq'::regclass) not null,
  concurso_id integer,
  numero integer not null,
  nombre text
);

create table if not exists public.catadores (
  id integer default nextval('catadores_id_seq'::regclass) not null,
  nombre text not null,
  rol text default 'catador'::text not null,
  mesa_id integer,
  activo boolean default false,
  pais_codigo text,
  titulo text,
  mesa integer,
  pais text,
  puesto smallint
);

create table if not exists public.dispositivos (
  id integer default nextval('dispositivos_id_seq'::regclass) not null,
  device_id text not null,
  catador_id integer,
  ultima_vez timestamp with time zone default now()
);

create table if not exists public.muestras (
  id integer default nextval('muestras_id_seq'::regclass) not null,
  concurso_id integer,
  categoria_id integer,
  codigo_ciego text not null,
  codigo_texto text,
  activo boolean default true
);

create table if not exists public.tandas (
  id integer default nextval('tandas_id_seq'::regclass) not null,
  mesa_id integer,
  numero integer not null,
  estado text default 'pendiente'::text,
  categoria_id integer,
  dia_id integer
);

create table if not exists public.tanda_muestras (
  id integer default nextval('tanda_muestras_id_seq'::regclass) not null,
  tanda_id integer not null,
  muestra_id integer not null,
  orden integer not null,
  estado text default 'pendiente'::text,
  incidencia_motivo text
);

create table if not exists public.puntuaciones (
  id integer default nextval('puntuaciones_id_seq'::regclass) not null,
  catador_id integer not null,
  muestra_id integer not null,
  tanda_id integer not null,
  scores jsonb not null,
  total numeric not null,
  estado text default 'borrador'::text,
  updated_at timestamp with time zone default now()
);

create table if not exists public.medallas (
  id integer default nextval('medallas_id_seq'::regclass) not null,
  muestra_id integer not null,
  media_final numeric not null,
  medalla text,
  aprobada_at timestamp with time zone default now()
);

create table if not exists public.asignaciones (
  id integer default nextval('asignaciones_id_seq'::regclass) not null,
  dia_id integer not null,
  catador_id integer not null,
  mesa_id integer not null,
  puesto integer not null,
  rol text not null,
  tablet_id integer,
  created_at timestamp with time zone default now()
);

create table if not exists public.registro_cambios (
  id uuid default gen_random_uuid() not null,
  dia_id integer,
  creado_en timestamp with time zone default now() not null,
  accion text not null,
  tabla text,
  registro_id text,
  antes jsonb,
  despues jsonb,
  motivo text
);

create table if not exists public.sync_estado (
  id integer default 1 not null,
  dia_id integer,
  estado text default 'vacio'::text not null,
  actualizado_en timestamp with time zone default now() not null,
  modo_pruebas boolean default true not null
);

create table if not exists public.despertador_tabla (
  id integer default nextval('despertador_tabla_id_seq'::regclass) not null,
  created_at timestamp with time zone default now(),
  fecha_grabacion timestamp with time zone default now(),
  make text default 'Despierta'::text
);

create table if not exists public.keepalive (
  id bigint generated by default as identity not null,
  created_at timestamp with time zone default now() not null
);

-- ---------- restricciones (idempotente) ----------
do $$
declare s text;
begin
  foreach s in array array[
    'alter table public.asignaciones add constraint asignaciones_pkey PRIMARY KEY (id)',
    'alter table public.catadores add constraint catadores_pkey PRIMARY KEY (id)',
    'alter table public.categorias add constraint categorias_pkey PRIMARY KEY (id)',
    'alter table public.concursos add constraint concursos_pkey PRIMARY KEY (id)',
    'alter table public.despertador_tabla add constraint despertador_tabla_pkey PRIMARY KEY (id)',
    'alter table public.dias_concurso add constraint dias_concurso_pkey PRIMARY KEY (id)',
    'alter table public.dispositivos add constraint dispositivos_pkey PRIMARY KEY (id)',
    'alter table public.keepalive add constraint keepalive_pkey PRIMARY KEY (id)',
    'alter table public.medallas add constraint medallas_pkey PRIMARY KEY (id)',
    'alter table public.mesas add constraint mesas_pkey PRIMARY KEY (id)',
    'alter table public.muestras add constraint muestras_pkey PRIMARY KEY (id)',
    'alter table public.puntuaciones add constraint puntuaciones_pkey PRIMARY KEY (id)',
    'alter table public.registro_cambios add constraint registro_cambios_pkey PRIMARY KEY (id)',
    'alter table public.sync_estado add constraint sync_estado_pkey PRIMARY KEY (id)',
    'alter table public.tanda_muestras add constraint tanda_muestras_pkey PRIMARY KEY (id)',
    'alter table public.tandas add constraint tandas_pkey PRIMARY KEY (id)',
    'alter table public.categorias add constraint categorias_codigo_key UNIQUE (codigo)',
    'alter table public.dispositivos add constraint dispositivos_catador_id_unico UNIQUE (catador_id)',
    'alter table public.dispositivos add constraint dispositivos_device_id_key UNIQUE (device_id)',
    'alter table public.muestras add constraint muestras_codigo_ciego_unico UNIQUE (codigo_ciego)',
    'alter table public.puntuaciones add constraint puntuacion_unica UNIQUE (catador_id, muestra_id)',
    'alter table public.tanda_muestras add constraint tanda_muestra_unique UNIQUE (tanda_id, muestra_id)',
    'alter table public.sync_estado add constraint sync_estado_estado_check CHECK ((estado = ANY (ARRAY[''vacio''::text, ''cargado''::text, ''subido''::text, ''verificado''::text])))',
    'alter table public.sync_estado add constraint sync_estado_id_check CHECK ((id = 1))',
    'alter table public.catadores add constraint catadores_mesa_id_fkey FOREIGN KEY (mesa_id) REFERENCES public.mesas(id)',
    'alter table public.dispositivos add constraint dispositivos_catador_id_fkey FOREIGN KEY (catador_id) REFERENCES public.catadores(id)',
    'alter table public.mesas add constraint mesas_concurso_id_fkey FOREIGN KEY (concurso_id) REFERENCES public.concursos(id)',
    'alter table public.muestras add constraint muestras_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id)',
    'alter table public.muestras add constraint muestras_concurso_id_fkey FOREIGN KEY (concurso_id) REFERENCES public.concursos(id)',
    'alter table public.registro_cambios add constraint registro_cambios_dia_id_fkey FOREIGN KEY (dia_id) REFERENCES public.dias_concurso(id)',
    'alter table public.sync_estado add constraint sync_estado_dia_id_fkey FOREIGN KEY (dia_id) REFERENCES public.dias_concurso(id)',
    'alter table public.tandas add constraint tandas_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id)',
    'alter table public.tandas add constraint tandas_dia_id_fkey FOREIGN KEY (dia_id) REFERENCES public.dias_concurso(id)',
    'alter table public.tandas add constraint tandas_mesa_id_fkey FOREIGN KEY (mesa_id) REFERENCES public.mesas(id)'
  ] loop
    begin
      execute s;
    exception when duplicate_object or duplicate_table or invalid_table_definition then null;
    end;
  end loop;
end $$;

alter sequence public.concursos_id_seq owned by public.concursos.id;
alter sequence public.categorias_id_seq owned by public.categorias.id;
alter sequence public.mesas_id_seq owned by public.mesas.id;
alter sequence public.catadores_id_seq owned by public.catadores.id;
alter sequence public.dispositivos_id_seq owned by public.dispositivos.id;
alter sequence public.muestras_id_seq owned by public.muestras.id;
alter sequence public.tandas_id_seq owned by public.tandas.id;
alter sequence public.tanda_muestras_id_seq owned by public.tanda_muestras.id;
alter sequence public.puntuaciones_id_seq owned by public.puntuaciones.id;
alter sequence public.medallas_id_seq owned by public.medallas.id;
alter sequence public.dias_concurso_id_seq owned by public.dias_concurso.id;
alter sequence public.asignaciones_id_seq owned by public.asignaciones.id;
alter sequence public.despertador_tabla_id_seq owned by public.despertador_tabla.id;

create index if not exists idx_dispositivos_device on public.dispositivos using btree (device_id);
create index if not exists idx_muestras_concurso on public.muestras using btree (concurso_id);
create index if not exists idx_pun_muestra on public.puntuaciones using btree (muestra_id);
create index if not exists idx_pun_catador on public.puntuaciones using btree (catador_id);
create index if not exists idx_pun_tanda on public.puntuaciones using btree (tanda_id);
create index if not exists idx_tm_tanda on public.tanda_muestras using btree (tanda_id);
create index if not exists idx_tm_estado on public.tanda_muestras using btree (tanda_id, estado);
create index if not exists idx_tandas_mesa on public.tandas using btree (mesa_id);
create unique index if not exists idx_medallas_muestra on public.medallas using btree (muestra_id);

-- ---------- funciones ----------
create or replace function public.keepalive_ping() returns void language plpgsql as $function$
begin
  insert into keepalive (created_at) values (now());
end;
$function$;

create or replace function public.ping() returns void language plpgsql as $function$ begin
end; $function$;

create or replace function public._buscar_tanda_muestra(p_codigo text, p_tanda integer default null::integer)
 returns integer language plpgsql as $function$
declare
  v_ids integer[];
  v_tandas text;
begin
  select array_agg(tm.id order by tm.id), string_agg(distinct t.numero::text, ', ')
    into v_ids, v_tandas
  from tanda_muestras tm
  join muestras m on m.id = tm.muestra_id
  join tandas t on t.id = tm.tanda_id
  where (m.codigo_ciego = p_codigo
         or case when m.codigo_ciego ~ '^[0-9]{1,9}$' then m.codigo_ciego::int end
          = case when p_codigo ~ '^[0-9]{1,9}$' then p_codigo::int end)
    and (p_tanda is null or t.numero = p_tanda);

  if v_ids is null then
    raise exception 'No encuentro la muestra % (tanda: %)', p_codigo, coalesce(p_tanda::text, 'cualquiera');
  end if;
  if array_length(v_ids, 1) > 1 then
    raise exception 'La muestra % está en varias tandas (%). Repite indicando la tanda, por ejemplo: select pasar_al_final(''%'', 901);', p_codigo, v_tandas, p_codigo;
  end if;
  return v_ids[1];
end $function$;

create or replace function public._renumerar_tanda(p_tanda integer) returns void language sql as $function$
  update tanda_muestras x set orden = n.nuevo
  from (select id, row_number() over (order by orden, id) as nuevo
        from tanda_muestras where tanda_id = p_tanda) n
  where x.id = n.id and x.orden is distinct from n.nuevo;
$function$;

create or replace function public._retirar_notas(p_tm integer, p_accion text, p_motivo text)
 returns integer language plpgsql as $function$
declare
  v_tanda integer;
  v_muestra integer;
  v_dia integer;
  v_notas jsonb;
  v_n integer;
begin
  select tm.tanda_id, tm.muestra_id, t.dia_id into v_tanda, v_muestra, v_dia
  from tanda_muestras tm join tandas t on t.id = tm.tanda_id
  where tm.id = p_tm;

  select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb), count(*) into v_notas, v_n
  from puntuaciones p
  where p.tanda_id = v_tanda and p.muestra_id = v_muestra;

  insert into registro_cambios (dia_id, accion, tabla, registro_id, antes, despues, motivo)
  values (v_dia, p_accion, 'tanda_muestras', p_tm::text,
          jsonb_build_object('notas', v_notas,
                             'tanda_muestra', (select to_jsonb(x) from tanda_muestras x where x.id = p_tm)),
          null, p_motivo);

  delete from puntuaciones where tanda_id = v_tanda and muestra_id = v_muestra;
  return v_n;
end $function$;

create or replace function public.pasar_al_final(p_codigo text, p_tanda integer default null::integer, p_motivo text default null::text)
 returns text language plpgsql as $function$
declare
  v_tm integer;
  v_tanda integer;
  v_n integer;
begin
  v_tm := _buscar_tanda_muestra(p_codigo, p_tanda);
  select tanda_id into v_tanda from tanda_muestras where id = v_tm;
  v_n := _retirar_notas(v_tm, 'pasar_al_final', p_motivo);
  update tanda_muestras
     set estado = 'pendiente', incidencia_motivo = null,
         orden = (select coalesce(max(orden), 0) + 1 from tanda_muestras where tanda_id = v_tanda)
   where id = v_tm;
  perform _renumerar_tanda(v_tanda);
  return format('Muestra %s pasada al final de la tanda (%s notas borradas y guardadas en el registro).', p_codigo, v_n);
end $function$;

create or replace function public.quitar_de_tanda(p_codigo text, p_tanda integer default null::integer, p_motivo text default null::text)
 returns text language plpgsql as $function$
declare
  v_tm integer;
  v_tanda integer;
  v_muestra integer;
  v_n integer;
begin
  v_tm := _buscar_tanda_muestra(p_codigo, p_tanda);
  select tanda_id, muestra_id into v_tanda, v_muestra from tanda_muestras where id = v_tm;
  v_n := _retirar_notas(v_tm, 'quitar_de_tanda', p_motivo);
  delete from tanda_muestras where id = v_tm;
  update muestras set activo = false where id = v_muestra;
  perform _renumerar_tanda(v_tanda);
  return format('Muestra %s quitada de la tanda y marcada como inactiva (%s notas borradas y guardadas en el registro).', p_codigo, v_n);
end $function$;

create or replace function public.recatar_muestra(p_codigo text, p_tanda integer default null::integer, p_motivo text default null::text)
 returns text language plpgsql as $function$
declare
  v_tm integer;
  v_n integer;
begin
  v_tm := _buscar_tanda_muestra(p_codigo, p_tanda);
  v_n := _retirar_notas(v_tm, 'recatar', p_motivo);
  update tanda_muestras set estado = 'pendiente', incidencia_motivo = null where id = v_tm;
  return format('Muestra %s lista para recatar desde cero (%s notas borradas y guardadas en el registro).', p_codigo, v_n);
end $function$;

create or replace function public.demo_reiniciar_muestra(p_tanda_muestra_id integer)
 returns text language plpgsql security definer set search_path to 'public' as $function$
declare
  v_muestra int;
  v_tanda int;
  v_cod text;
begin
  select tm.muestra_id, tm.tanda_id, mu.codigo_texto
    into v_muestra, v_tanda, v_cod
  from tanda_muestras tm
  join muestras mu on mu.id = tm.muestra_id
  where tm.id = p_tanda_muestra_id;

  if v_cod is null or v_cod not like 'DEMO-%' then
    raise exception 'SOLO_DEMO: esta función solo actúa sobre muestras DEMO';
  end if;

  delete from puntuaciones where muestra_id = v_muestra and tanda_id = v_tanda;
  update tanda_muestras
    set estado = 'pendiente', incidencia_motivo = null
    where id = p_tanda_muestra_id;

  return 'OK';
end $function$;

create or replace function public.bloquear_puntuacion_aprobada() returns trigger language plpgsql as $function$
begin
  -- Reapertura autorizada por el administrador (la activa reabrir_muestra)
  if current_setting('virtus.reabrir', true) = 'on' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if exists (
      select 1 from puntuaciones
      where muestra_id = new.muestra_id
        and tanda_id = new.tanda_id
        and estado = 'aprobada'
    ) then
      raise exception 'MUESTRA_APROBADA: esta muestra ya fue aprobada y no admite cambios';
    end if;
    return new;
  end if;

  if new.scores is distinct from old.scores
     or new.total is distinct from old.total
     or (old.estado = 'aprobada' and new.estado is distinct from old.estado) then
    if old.estado = 'aprobada' or exists (
      select 1 from puntuaciones
      where muestra_id = old.muestra_id
        and tanda_id = old.tanda_id
        and estado = 'aprobada'
        and id <> old.id
    ) then
      raise exception 'MUESTRA_APROBADA: esta muestra ya fue aprobada y no admite cambios';
    end if;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_bloquear_puntuacion_aprobada on public.puntuaciones;
create trigger trg_bloquear_puntuacion_aprobada before insert or update on public.puntuaciones
  for each row execute function public.bloquear_puntuacion_aprobada();

-- ---------- RLS (igual que cloud) ----------
alter table public.asignaciones enable row level security;
alter table public.catadores enable row level security;
alter table public.categorias enable row level security;
alter table public.concursos enable row level security;
alter table public.despertador_tabla enable row level security;
alter table public.dias_concurso enable row level security;
alter table public.dispositivos enable row level security;
alter table public.keepalive enable row level security;
alter table public.medallas enable row level security;
alter table public.mesas enable row level security;
alter table public.muestras enable row level security;
alter table public.puntuaciones enable row level security;
alter table public.registro_cambios enable row level security;
alter table public.sync_estado enable row level security;
alter table public.tanda_muestras enable row level security;
alter table public.tandas enable row level security;

drop policy if exists lectura_publica on public.concursos;
create policy lectura_publica on public.concursos for select to public using (true);
drop policy if exists lectura_publica on public.mesas;
create policy lectura_publica on public.mesas for select to public using (true);
drop policy if exists escritura_dispositivos on public.dispositivos;
create policy escritura_dispositivos on public.dispositivos for all to public using (true) with check (true);
drop policy if exists lectura_publica on public.dispositivos;
create policy lectura_publica on public.dispositivos for select to public using (true);
drop policy if exists lectura_publica on public.categorias;
create policy lectura_publica on public.categorias for select to public using (true);
drop policy if exists lectura_publica on public.muestras;
create policy lectura_publica on public.muestras for select to public using (true);
drop policy if exists escritura_puntuaciones on public.puntuaciones;
create policy escritura_puntuaciones on public.puntuaciones for all to public using (true) with check (true);
drop policy if exists lectura_publica on public.puntuaciones;
create policy lectura_publica on public.puntuaciones for select to public using (true);
drop policy if exists escritura_tanda_muestras on public.tanda_muestras;
create policy escritura_tanda_muestras on public.tanda_muestras for all to public using (true) with check (true);
drop policy if exists lectura_publica on public.tanda_muestras;
create policy lectura_publica on public.tanda_muestras for select to public using (true);
drop policy if exists lectura_publica on public.tandas;
create policy lectura_publica on public.tandas for select to public using (true);
drop policy if exists lectura_publica on public.medallas;
create policy lectura_publica on public.medallas for select to public using (true);
drop policy if exists escritura_catadores on public.catadores;
create policy escritura_catadores on public.catadores for all to public using (true) with check (true);
drop policy if exists lectura_publica on public.catadores;
create policy lectura_publica on public.catadores for select to public using (true);
drop policy if exists make_write on public.despertador_tabla;
create policy make_write on public.despertador_tabla for all to public using (true) with check (true);
drop policy if exists lectura_publica on public.sync_estado;
create policy lectura_publica on public.sync_estado for select to public using (true);
drop policy if exists alta_registro on public.registro_cambios;
create policy alta_registro on public.registro_cambios for insert to public with check (true);
drop policy if exists lectura_publica on public.registro_cambios;
create policy lectura_publica on public.registro_cambios for select to public using (true);

insert into public.sync_estado (id) values (1) on conflict (id) do nothing;

-- ---------- realtime (igual que cloud) ----------
do $$
declare t text;
begin
  foreach t in array array['puntuaciones','tanda_muestras','tandas'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
