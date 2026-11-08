-- =============================================================================
-- Esquema COMPLETO Catas2027 + App Gestión (Virtus) para pegar en el SQL Editor
-- del Studio del Supabase LOCAL (p. ej. GEEKOM / Ubuntu nativo).
--
-- Origen: supabase/migrations/*.sql en orden cronológico.
-- Uso: pegar TODO este archivo y ejecutar. Se puede repetir: al inicio reinicia
--      el esquema public (borra tablas/datos de concurso) y lo recrea.
--
-- NO toca: auth, storage, roles de Supabase, ni el proyecto Cloud.
-- Auth: los usuarios de Authentication se conservan (viven fuera de public).
-- =============================================================================

-- ---------- reinicio limpio de public (esquema idéntico al repo, sin datos) ----------
drop schema if exists public cascade;
create schema public;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;
grant all on schema public to public;
alter default privileges in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to postgres, anon, authenticated, service_role;



-- ##### BEGIN 20260607000000_base_catas2027.sql #####

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
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'publicación supabase_realtime ausente: se omite realtime (base)';
    return;
  end if;
  foreach t in array array['puntuaciones','tanda_muestras','tandas'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
exception
  when insufficient_privilege then
    raise notice 'realtime (base) omitido: sin privilegio sobre la publicación';
end $$;

-- ##### END 20260607000000_base_catas2027.sql #####


-- ##### BEGIN 20261106000000_app_gestion.sql #####

-- =====================================================================
-- App de gestión Virtus Catas 2027 · cambios ADITIVOS sobre Catas2027.
-- No borra ni renombra nada; las tablets existentes siguen funcionando.
--  * updated_at en todas las tablas sincronizables (last-write-wins)
--  * sync_borrados: registro de borrados para propagarlos entre entornos
--  * tandas.orden (orden de trabajo) y catadores.presente
--  * escritura para usuarios AUTENTICADOS en las tablas de configuración
--  * RPCs de gestión: puestos, orden, incidencias, aprobación y medallas
-- =====================================================================

-- ---------- columnas nuevas ----------
alter table public.tandas    add column if not exists orden integer;
alter table public.catadores add column if not exists presente boolean not null default true;

update public.tandas t set orden = x.n - 1
from (select id, row_number() over (partition by mesa_id, dia_id order by numero, id) n from public.tandas) x
where t.id = x.id and t.orden is null;

do $$
declare t text;
begin
  foreach t in array array['concursos','categorias','dias_concurso','mesas','catadores','muestras',
                           'tandas','tanda_muestras','medallas','asignaciones'] loop
    execute format('alter table public.%I add column if not exists updated_at timestamptz not null default now()', t);
  end loop;
end $$;

-- ---------- updated_at automático (respeta el valor que trae la sincronización) ----------
create or replace function public.tg_sync_touch()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.updated_at is distinct from old.updated_at
     and new.updated_at > old.updated_at then
    return new;
  end if;
  if tg_op = 'INSERT' and new.updated_at is not null
     and current_setting('virtus.sync', true) = 'on' then
    return new;
  end if;
  new.updated_at := now();
  return new;
end $$;

-- ---------- registro de borrados ----------
create table if not exists public.sync_borrados (
  id          bigint generated by default as identity primary key,
  tabla       text not null,
  registro_id integer not null,
  clave       jsonb,
  borrado_en  timestamptz not null default now()
);
create index if not exists sync_borrados_en on public.sync_borrados (borrado_en);
alter table public.sync_borrados enable row level security;

create or replace function public.tg_sync_borrado()
returns trigger language plpgsql security definer set search_path = public as $$
declare v jsonb := to_jsonb(old);
begin
  insert into public.sync_borrados (tabla, registro_id, clave)
  values (tg_table_name, old.id,
          case tg_table_name
            when 'puntuaciones'   then jsonb_build_object('catador_id', v->'catador_id', 'muestra_id', v->'muestra_id')
            when 'tanda_muestras' then jsonb_build_object('tanda_id', v->'tanda_id', 'muestra_id', v->'muestra_id')
          end);
  return old;
end $$;

do $$
declare t text;
begin
  foreach t in array array['concursos','categorias','dias_concurso','mesas','catadores','muestras',
                           'tandas','tanda_muestras','puntuaciones','medallas','asignaciones'] loop
    execute format('drop trigger if exists trg_sync_touch on public.%I', t);
    execute format('create trigger trg_sync_touch before insert or update on public.%I
                    for each row execute function public.tg_sync_touch()', t);
    execute format('drop trigger if exists trg_sync_borrado on public.%I', t);
    execute format('create trigger trg_sync_borrado after delete on public.%I
                    for each row execute function public.tg_sync_borrado()', t);
    execute format('create index if not exists %I on public.%I (updated_at)', t || '_updated_at', t);
  end loop;
end $$;

-- ---------- permisos: la app de gestión escribe con usuario autenticado ----------
do $$
declare t text;
begin
  foreach t in array array['concursos','categorias','dias_concurso','mesas','muestras','tandas',
                           'medallas','asignaciones','sync_estado'] loop
    execute format('drop policy if exists gestion_autenticados on public.%I', t);
    execute format('create policy gestion_autenticados on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

drop policy if exists gestion_autenticados on public.sync_borrados;
create policy gestion_autenticados on public.sync_borrados for all to authenticated using (true) with check (true);

-- ---------- realtime para el panel en directo ----------
do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'publicación supabase_realtime ausente: se omite realtime (gestión)';
    return;
  end if;
  foreach t in array array['concursos','dias_concurso','mesas','catadores','muestras','medallas',
                           'registro_cambios','puntuaciones','tanda_muestras','tandas'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
exception
  when insufficient_privilege then
    raise notice 'realtime (gestión) omitido: sin privilegio sobre la publicación';
end $$;

-- =====================================================================
-- RPCs de gestión (security invoker: respetan RLS)
-- =====================================================================

-- Dia de la tanda (para el registro de cambios)
create or replace function public._dia_de_tanda(p_tanda integer)
returns integer language sql stable as $$ select dia_id from public.tandas where id = p_tanda $$;

-- Intercambia mesa y puesto de dos catadores
create or replace function public.intercambiar_puestos(a integer, b integer, p_motivo text default null)
returns void language plpgsql as $$
declare ra public.catadores; rb public.catadores;
begin
  select * into ra from public.catadores where id = a for update;
  select * into rb from public.catadores where id = b for update;
  if ra.id is null or rb.id is null then raise exception 'Catador no encontrado'; end if;
  update public.catadores set mesa_id = rb.mesa_id, mesa = rb.mesa, puesto = rb.puesto where id = a;
  update public.catadores set mesa_id = ra.mesa_id, mesa = ra.mesa, puesto = ra.puesto where id = b;
  insert into public.registro_cambios (accion, tabla, registro_id, antes, despues, motivo)
  values ('cambio_puesto', 'catadores', a || ',' || b,
          jsonb_build_object(ra.nombre, jsonb_build_object('mesa', ra.mesa, 'puesto', ra.puesto),
                             rb.nombre, jsonb_build_object('mesa', rb.mesa, 'puesto', rb.puesto)),
          jsonb_build_object(ra.nombre, jsonb_build_object('mesa', rb.mesa, 'puesto', rb.puesto),
                             rb.nombre, jsonb_build_object('mesa', ra.mesa, 'puesto', ra.puesto)),
          coalesce(p_motivo, 'Intercambio de puestos'));
end $$;

-- Mueve un catador a una mesa/puesto (si está ocupado, intercambia)
create or replace function public.mover_catador(p_catador integer, p_mesa integer, p_puesto integer, p_motivo text default null)
returns void language plpgsql as $$
declare r public.catadores; v_otro integer; v_num integer;
begin
  select * into r from public.catadores where id = p_catador for update;
  if r.id is null then raise exception 'Catador no encontrado'; end if;
  select id into v_otro from public.catadores
   where mesa_id = p_mesa and puesto = p_puesto and id <> p_catador limit 1;
  if v_otro is not null then
    perform public.intercambiar_puestos(p_catador, v_otro, p_motivo);
    return;
  end if;
  select numero into v_num from public.mesas where id = p_mesa;
  update public.catadores set mesa_id = p_mesa, mesa = v_num, puesto = p_puesto where id = p_catador;
  insert into public.registro_cambios (accion, tabla, registro_id, antes, despues, motivo)
  values ('cambio_puesto', 'catadores', p_catador::text,
          jsonb_build_object('mesa', r.mesa, 'puesto', r.puesto),
          jsonb_build_object('mesa', v_num, 'puesto', p_puesto),
          coalesce(p_motivo, r.nombre || ' cambia de puesto'));
end $$;

-- Reordena las tandas (ids en el orden deseado)
create or replace function public.reordenar_tandas(ids integer[], p_motivo text default null)
returns void language plpgsql as $$
begin
  update public.tandas t set orden = x.ord - 1
    from unnest(ids) with ordinality as x(id, ord)
   where t.id = x.id and t.orden is distinct from x.ord - 1;
  insert into public.registro_cambios (dia_id, accion, tabla, registro_id, despues, motivo)
  values (public._dia_de_tanda(ids[1]), 'cambio_orden_tandas', 'tandas', array_to_string(ids, ','),
          to_jsonb(ids), p_motivo);
end $$;

-- Reordena las muestras de una tanda (orden 1..n, como usan las tablets)
create or replace function public.reordenar_muestras(p_tanda integer, ids integer[], p_motivo text default null)
returns void language plpgsql as $$
begin
  update public.tanda_muestras tm set orden = x.ord
    from unnest(ids) with ordinality as x(id, ord)
   where tm.id = x.id and tm.tanda_id = p_tanda and tm.orden is distinct from x.ord;
  perform public._renumerar_tanda(p_tanda);
  insert into public.registro_cambios (dia_id, accion, tabla, registro_id, despues, motivo)
  values (public._dia_de_tanda(p_tanda), 'cambio_orden_muestras', 'tanda_muestras', p_tanda::text,
          to_jsonb(ids), p_motivo);
end $$;

-- Marca una muestra con incidencia
create or replace function public.marcar_incidencia(p_tm integer, p_motivo text)
returns void language plpgsql as $$
declare r public.tanda_muestras;
begin
  select * into r from public.tanda_muestras where id = p_tm for update;
  if r.id is null then raise exception 'Muestra de tanda no encontrada'; end if;
  update public.tanda_muestras set estado = 'incidencia', incidencia_motivo = p_motivo where id = p_tm;
  insert into public.registro_cambios (dia_id, accion, tabla, registro_id, antes, motivo)
  values (public._dia_de_tanda(r.tanda_id), 'incidencia', 'tanda_muestras', p_tm::text, to_jsonb(r), p_motivo);
end $$;

-- Resuelve una incidencia: recatar | pasar_al_final | quitar_de_tanda | continuar
create or replace function public.resolver_incidencia(p_tm integer, p_accion text, p_motivo text default null)
returns text language plpgsql as $$
declare v_cod text; v_num integer; r public.tanda_muestras;
begin
  select * into r from public.tanda_muestras where id = p_tm;
  if r.id is null then raise exception 'Muestra de tanda no encontrada'; end if;
  select m.codigo_ciego, t.numero into v_cod, v_num
    from public.muestras m, public.tandas t where m.id = r.muestra_id and t.id = r.tanda_id;
  case p_accion
    when 'recatar'         then return public.recatar_muestra(v_cod, v_num, p_motivo);
    when 'pasar_al_final'  then return public.pasar_al_final(v_cod, v_num, p_motivo);
    when 'quitar_de_tanda' then return public.quitar_de_tanda(v_cod, v_num, p_motivo);
    when 'continuar' then
      update public.tanda_muestras set estado = 'pendiente' where id = p_tm;
      insert into public.registro_cambios (dia_id, accion, tabla, registro_id, antes, motivo)
      values (public._dia_de_tanda(r.tanda_id), 'incidencia_resuelta', 'tanda_muestras', p_tm::text, to_jsonb(r),
              coalesce(p_motivo, 'Se continúa sin cambios'));
      return format('Muestra %s: incidencia cerrada, sigue pendiente.', v_cod);
    else raise exception 'Acción no válida: %', p_accion;
  end case;
end $$;

-- Pone una muestra como la activa de su tanda (la que ven las tablets)
create or replace function public.activar_muestra(p_tm integer)
returns void language plpgsql as $$
declare v_tanda integer;
begin
  select tanda_id into v_tanda from public.tanda_muestras where id = p_tm;
  update public.tanda_muestras set estado = 'pendiente'
   where tanda_id = v_tanda and estado = 'activa' and id <> p_tm;
  update public.tanda_muestras set estado = 'activa' where id = p_tm;
end $$;

-- Aprueba las notas enviadas de una muestra en su tanda y la da por completada
create or replace function public.aprobar_muestra(p_tm integer)
returns integer language plpgsql as $$
declare r public.tanda_muestras; v_n integer;
begin
  select * into r from public.tanda_muestras where id = p_tm;
  update public.puntuaciones set estado = 'aprobada'
   where tanda_id = r.tanda_id and muestra_id = r.muestra_id and estado is distinct from 'aprobada';
  get diagnostics v_n = row_count;
  update public.tanda_muestras set estado = 'completada' where id = p_tm;
  insert into public.registro_cambios (dia_id, accion, tabla, registro_id, motivo)
  values (public._dia_de_tanda(r.tanda_id), 'aprobar_muestra', 'tanda_muestras', p_tm::text,
          v_n || ' notas aprobadas desde la app de gestión');
  return v_n;
end $$;

-- Fija (o quita) la medalla oficial de una muestra
create or replace function public.fijar_medalla(p_muestra integer, p_medalla text, p_media numeric)
returns void language plpgsql as $$
begin
  if p_medalla is null then
    delete from public.medallas where muestra_id = p_muestra;
  else
    insert into public.medallas (muestra_id, media_final, medalla, aprobada_at)
    values (p_muestra, p_media, p_medalla, now())
    on conflict (muestra_id) do update
      set media_final = excluded.media_final, medalla = excluded.medalla, aprobada_at = now();
  end if;
end $$;

-- Tras bajar datos a LOCAL: las altas locales usan ids >= 1.000.000
-- para no chocar nunca con las de cloud al subir.
create or replace function public.sync_preparar_local()
returns void language plpgsql security definer set search_path = public as $$
declare s record;
begin
  for s in
    select seq.relname as seq, tab.relname as tab
    from pg_class seq
    join pg_depend d on d.objid = seq.oid and d.deptype = 'a'
    join pg_class tab on tab.oid = d.refobjid
    where seq.relkind = 'S' and seq.relnamespace = 'public'::regnamespace
  loop
    execute format('select setval(%L, greatest(1000000, (select coalesce(max(id), 0) + 1 from public.%I), nextval(%L)))',
                   'public.' || s.seq, s.tab, 'public.' || s.seq);
  end loop;
end $$;
revoke execute on function public.sync_preparar_local() from public, anon;
grant execute on function public.sync_preparar_local() to authenticated;

-- Aplica en bloque las filas de la sincronización conservando su updated_at
create or replace function public.sync_aplicar(p_tabla text, p_filas jsonb)
returns integer language plpgsql as $$
declare v_n integer; v_conf text; v_cols text;
begin
  if p_tabla = 'registro_cambios' then
    insert into public.registro_cambios
    select * from jsonb_populate_recordset(null::public.registro_cambios, p_filas)
    on conflict (id) do nothing;
    get diagnostics v_n = row_count;
    return v_n;
  end if;
  if p_tabla not in ('concursos','categorias','dias_concurso','mesas','catadores','muestras',
                     'tandas','tanda_muestras','puntuaciones','medallas','asignaciones') then
    raise exception 'Tabla no sincronizable: %', p_tabla;
  end if;
  perform set_config('virtus.sync', 'on', true);
  perform set_config('virtus.reabrir', 'on', true);  -- la sync puede traer notas ya aprobadas
  v_conf := case p_tabla
              when 'puntuaciones'   then 'catador_id, muestra_id'
              when 'tanda_muestras' then 'tanda_id, muestra_id'
              when 'medallas'       then 'muestra_id'
              else 'id' end;
  select string_agg(format('%I = excluded.%I', column_name, column_name), ', ')
    into v_cols
    from information_schema.columns
   where table_schema = 'public' and table_name = p_tabla
     and column_name <> 'id' and column_name <> all (string_to_array(replace(v_conf, ' ', ''), ','));
  execute format(
    'insert into public.%1$I select * from jsonb_populate_recordset(null::public.%1$I, $1) r
     on conflict (%2$s) do update set %3$s
     where public.%1$I.updated_at is null or excluded.updated_at > public.%1$I.updated_at',
    p_tabla, v_conf, v_cols) using p_filas;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- Aplica borrados recibidos de la sincronización (solo si no hubo cambios posteriores)
create or replace function public.sync_borrar(p_borrados jsonb)
returns integer language plpgsql as $$
declare b jsonb; v_n integer := 0; v_c integer;
begin
  perform set_config('virtus.reabrir', 'on', true);
  for b in select * from jsonb_array_elements(p_borrados) loop
    if b->>'tabla' not in ('concursos','categorias','dias_concurso','mesas','catadores','muestras',
                           'tandas','tanda_muestras','puntuaciones','medallas','asignaciones') then
      continue;
    end if;
    if b->>'tabla' = 'puntuaciones' then
      delete from public.puntuaciones
       where catador_id = (b->'clave'->>'catador_id')::int and muestra_id = (b->'clave'->>'muestra_id')::int
         and updated_at <= (b->>'borrado_en')::timestamptz;
    elsif b->>'tabla' = 'tanda_muestras' then
      delete from public.tanda_muestras
       where tanda_id = (b->'clave'->>'tanda_id')::int and muestra_id = (b->'clave'->>'muestra_id')::int
         and updated_at <= (b->>'borrado_en')::timestamptz;
    else
      execute format('delete from public.%I where id = $1 and updated_at <= $2', b->>'tabla')
        using (b->>'registro_id')::int, (b->>'borrado_en')::timestamptz;
    end if;
    get diagnostics v_c = row_count;
    v_n := v_n + v_c;
  end loop;
  return v_n;
end $$;

-- ---------- Resultados para medallas ----------
do $vista$
begin
  execute $q$
create or replace view public.v_resultados_gestion
with (security_invoker = true) as
with notas as (
  select p.muestra_id, p.total, p.estado
  from public.puntuaciones p
  where p.estado in ('enviada', 'aprobada')
),
agg as (
  select muestra_id,
         count(*)                                  as n_notas,
         count(*) filter (where estado = 'aprobada') as n_aprobadas,
         round(avg(total), 2)                      as media,
         min(total) as minimo, max(total) as maximo
  from notas group by muestra_id
)
select m.id as muestra_id, m.concurso_id, m.categoria_id, m.codigo_ciego, m.codigo_texto, m.activo,
       coalesce(a.n_notas, 0) as n_notas, coalesce(a.n_aprobadas, 0) as n_aprobadas,
       a.media, a.minimo, a.maximo,
       (m.codigo_ciego ~ '^[0-9]{1,9}$' and m.codigo_ciego::int < 1000) as no_premia,
       case
         when a.media is null then null
         when m.codigo_ciego ~ '^[0-9]{1,9}$' and m.codigo_ciego::int < 1000 then 'sin_medalla'
         when a.media >= c.gran_oro then 'gran_oro'
         when a.media >= c.oro then 'oro'
         when a.media >= c.plata then 'plata'
         else 'sin_medalla'
       end as medalla_propuesta,
       md.medalla as medalla_oficial,
       md.media_final as media_oficial
from public.muestras m
left join public.concursos c on c.id = m.concurso_id
left join agg a on a.muestra_id = m.id
left join public.medallas md on md.muestra_id = m.id
$q$;
exception
  when syntax_error or feature_not_supported or undefined_object then
    execute $q$
create or replace view public.v_resultados_gestion as
with notas as (
  select p.muestra_id, p.total, p.estado
  from public.puntuaciones p
  where p.estado in ('enviada', 'aprobada')
),
agg as (
  select muestra_id,
         count(*)                                  as n_notas,
         count(*) filter (where estado = 'aprobada') as n_aprobadas,
         round(avg(total), 2)                      as media,
         min(total) as minimo, max(total) as maximo
  from notas group by muestra_id
)
select m.id as muestra_id, m.concurso_id, m.categoria_id, m.codigo_ciego, m.codigo_texto, m.activo,
       coalesce(a.n_notas, 0) as n_notas, coalesce(a.n_aprobadas, 0) as n_aprobadas,
       a.media, a.minimo, a.maximo,
       (m.codigo_ciego ~ '^[0-9]{1,9}$' and m.codigo_ciego::int < 1000) as no_premia,
       case
         when a.media is null then null
         when m.codigo_ciego ~ '^[0-9]{1,9}$' and m.codigo_ciego::int < 1000 then 'sin_medalla'
         when a.media >= c.gran_oro then 'gran_oro'
         when a.media >= c.oro then 'oro'
         when a.media >= c.plata then 'plata'
         else 'sin_medalla'
       end as medalla_propuesta,
       md.medalla as medalla_oficial,
       md.media_final as media_oficial
from public.muestras m
left join public.concursos c on c.id = m.concurso_id
left join agg a on a.muestra_id = m.id
left join public.medallas md on md.muestra_id = m.id
$q$;
    raise notice 'v_resultados_gestion creada sin security_invoker (Postgres antiguo)';
end $vista$;

-- Las RPCs de gestión son solo para usuarios autenticados (no para las tablets anónimas)
do $$
declare f text;
begin
  foreach f in array array[
    'intercambiar_puestos(integer, integer, text)', 'mover_catador(integer, integer, integer, text)',
    'reordenar_tandas(integer[], text)', 'reordenar_muestras(integer, integer[], text)',
    'marcar_incidencia(integer, text)', 'resolver_incidencia(integer, text, text)',
    'activar_muestra(integer)', 'aprobar_muestra(integer)', 'fijar_medalla(integer, text, numeric)',
    'sync_aplicar(text, jsonb)', 'sync_borrar(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ##### END 20261106000000_app_gestion.sql #####


-- ##### BEGIN 20261106000100_app_gestion_seguridad.sql #####

-- Endurecimiento de las funciones añadidas por la app de gestión
-- (search_path fijo y el trigger de borrados no expuesto por la API).
alter function public.tg_sync_touch() set search_path = public;
alter function public.tg_sync_borrado() set search_path = public;
alter function public._dia_de_tanda(integer) set search_path = public;
alter function public.intercambiar_puestos(integer, integer, text) set search_path = public;
alter function public.mover_catador(integer, integer, integer, text) set search_path = public;
alter function public.reordenar_tandas(integer[], text) set search_path = public;
alter function public.reordenar_muestras(integer, integer[], text) set search_path = public;
alter function public.marcar_incidencia(integer, text) set search_path = public;
alter function public.resolver_incidencia(integer, text, text) set search_path = public;
alter function public.activar_muestra(integer) set search_path = public;
alter function public.aprobar_muestra(integer) set search_path = public;
alter function public.fijar_medalla(integer, text, numeric) set search_path = public;
alter function public.sync_aplicar(text, jsonb) set search_path = public;
alter function public.sync_borrar(jsonb) set search_path = public;

revoke execute on function public.tg_sync_borrado() from public, anon, authenticated;

-- ##### END 20261106000100_app_gestion_seguridad.sql #####


-- ##### BEGIN 20261106000200_app_gestion_permisos.sql #####

-- resolver_incidencia y reordenar_muestras usan funciones internas del sistema
-- (recatar_muestra, pasar_al_final, quitar_de_tanda, _renumerar_tanda) que
-- solo puede ejecutar el propietario. En vez de abrir esas funciones, estas dos
-- se ejecutan como propietario y solo las pueden llamar usuarios autenticados.
alter function public.resolver_incidencia(integer, text, text) security definer;
alter function public.reordenar_muestras(integer, integer[], text) security definer;
revoke execute on function public.resolver_incidencia(integer, text, text) from public, anon;
revoke execute on function public.reordenar_muestras(integer, integer[], text) from public, anon;
grant execute on function public.resolver_incidencia(integer, text, text) to authenticated;
grant execute on function public.reordenar_muestras(integer, integer[], text) to authenticated;

-- ##### END 20261106000200_app_gestion_permisos.sql #####


-- ##### BEGIN 20261107000000_vista_resultados_permisos.sql #####

-- Permisos de lectura de la vista de resultados (medallas) para la app.
-- Idempotente: si la vista aún no existe en un LOCAL antiguo, no falla el resto.

do $$
begin
  if exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'v_resultados_gestion'
  ) then
    execute 'grant select on public.v_resultados_gestion to authenticated, anon';
  end if;
end $$;

-- ##### END 20261107000000_vista_resultados_permisos.sql #####


-- ##### BEGIN 20261108000000_funciones_cloud_faltantes.sql #####

-- Funciones que ya existían en Supabase Cloud (Catas2027) y faltaban en el repo.
-- Copiadas tal cual; sin cambiar comportamiento.
-- Enganches reales en Cloud:
--   rls_auto_enable()           → event trigger ensure_rls (ddl_command_end)
--   tg_muestra_codigos()        → trigger trg_muestra_codigos (BEFORE INSERT ON muestras)
--   scores_validos(jsonb)       → CHECK puntuaciones_scores_validos en puntuaciones.scores
--   siguiente_codigo_ciego(...) → llamada desde tg_muestra_codigos (y usable a mano)
-- Idempotente: se puede aplicar sobre Cloud (ya existen) y sobre Local (desde cero).
-- No toca los event triggers propios de Supabase (pgrst_*, issue_*).

-- ---------- funciones ----------

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.scores_validos(s jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_typeof(s) = 'object'
    AND NOT EXISTS (
      SELECT 1 FROM jsonb_each(s) AS e(k, v)
      WHERE NOT (
        jsonb_typeof(v) IN ('boolean', 'null')
        OR (jsonb_typeof(v) = 'number' AND (v #>> '{}')::numeric BETWEEN 0 AND 100)
      )
    );
$function$;

CREATE OR REPLACE FUNCTION public.siguiente_codigo_ciego(p_manual boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_lo int := case when p_manual then 1 else 1000 end;
  v_hi int := case when p_manual then 999 else 9999 end;
  v_n int;
begin
  -- Evita que dos inscripciones simultáneas elijan el mismo número.
  perform pg_advisory_xact_lock(hashtext('muestras_codigo_ciego'));

  if (select count(*) from muestras where codigo_ciego between v_lo and v_hi) >= v_hi - v_lo + 1 then
    raise exception 'CODIGOS_AGOTADOS: no quedan códigos libres entre % y %', v_lo, v_hi;
  end if;

  loop
    v_n := v_lo + floor(random() * (v_hi - v_lo + 1))::int;
    exit when not exists (select 1 from muestras where codigo_ciego = v_n);
  end loop;
  return v_n;
end $function$;

CREATE OR REPLACE FUNCTION public.tg_muestra_codigos()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.codigo_ciego is null then
    new.codigo_ciego := public.siguiente_codigo_ciego(false);
  end if;
  if new.codigo_texto is null then
    new.codigo_texto := lpad(new.codigo_ciego::text, 4, '0');
  end if;
  return new;
end $function$;

-- ---------- enganches ----------

-- Event trigger ensure_rls (función rls_auto_enable). Requiere superusuario;
-- si el rol del SQL Editor no puede crearlo, se omite sin abortar el script.
do $evt$
begin
  drop event trigger if exists rls_auto_enable;
  drop event trigger if exists ensure_rls;
  create event trigger ensure_rls
    on ddl_command_end
    execute function public.rls_auto_enable();
exception
  when insufficient_privilege then
    raise notice 'ensure_rls omitido: el rol actual no puede crear event triggers';
  when others then
    raise notice 'ensure_rls omitido: %', sqlerrm;
end $evt$;

-- Autocompletar codigo_ciego / codigo_texto al insertar muestras
drop trigger if exists trg_muestra_codigos on public.muestras;
create trigger trg_muestra_codigos
  before insert on public.muestras
  for each row execute function public.tg_muestra_codigos();

-- CHECK real en Cloud: puntuaciones_scores_validos (sin sufijo _check).
-- Quita el nombre erróneo de un borrador anterior si existiera.
alter table public.puntuaciones drop constraint if exists puntuaciones_scores_validos_check;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'puntuaciones_scores_validos'
      and conrelid = 'public.puntuaciones'::regclass
  ) then
    alter table public.puntuaciones
      add constraint puntuaciones_scores_validos
      check (public.scores_validos(scores));
  end if;
end $$;

-- ##### END 20261108000000_funciones_cloud_faltantes.sql #####

-- =============================================================================
-- Fin del esquema. Semilla de infraestructura (no es demo):
--   sync_estado id=1  → fila única que exige la app / sincronización.
-- No hay datos de concurso, catadores, muestras ni puntuaciones.
-- =============================================================================
