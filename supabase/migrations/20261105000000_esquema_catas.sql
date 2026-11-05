-- =====================================================================
-- VIRTUS · Gestión de Catas 2027 · Esquema base
-- Mismo esquema en Supabase CLOUD y LOCAL para poder sincronizar.
--  * PK uuid generadas en cliente o servidor (únicas entre entornos)
--  * updated_at automático  -> last-write-wins en la sincronización
--  * deleted_at (borrado lógico) -> los borrados también se sincronizan
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- utilidades ----------
create or replace function public.tg_touch_updated_at()
returns trigger language plpgsql as $$
begin
  -- Si la sincronización trae su propio updated_at más reciente, se respeta.
  if tg_op = 'UPDATE' and new.updated_at is distinct from old.updated_at
     and new.updated_at > old.updated_at then
    return new;
  end if;
  if tg_op = 'INSERT' and new.updated_at is not null then
    return new;
  end if;
  new.updated_at := now();
  return new;
end $$;

-- ---------- CATAS (edición / concurso) ----------
create table public.catas (
  id                uuid primary key default gen_random_uuid(),
  nombre            text not null,
  fecha             date,
  lugar             text,
  activa            boolean not null default true,
  escala_max        numeric(5,2) not null default 100,
  umbral_gran_oro   numeric(5,2) not null default 92,
  umbral_oro        numeric(5,2) not null default 85,
  umbral_plata      numeric(5,2) not null default 82,
  umbral_bronce     numeric(5,2),
  descartar_extremos boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz,
  deleted_at        timestamptz
);

-- ---------- MESAS ----------
create table public.mesas (
  id          uuid primary key default gen_random_uuid(),
  cata_id     uuid not null references public.catas(id) on delete cascade,
  numero      int  not null,
  nombre      text,
  sala        text,
  estado      text not null default 'preparada'
              check (estado in ('preparada','catando','pausa','finalizada')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz,
  deleted_at  timestamptz
);
create index on public.mesas (cata_id, numero);

-- ---------- CATADORES ----------
-- mesa_id + puesto = sitio que ocupa en la mesa. Sin UNIQUE para que
-- los intercambios y la sincronización nunca bloqueen; la app avisa
-- si hay dos catadores en el mismo puesto.
create table public.catadores (
  id            uuid primary key default gen_random_uuid(),
  cata_id       uuid not null references public.catas(id) on delete cascade,
  nombre        text not null,
  apellidos     text,
  email         text,
  telefono      text,
  pais          text,
  idioma        text default 'es',
  mesa_id       uuid references public.mesas(id) on delete set null,
  puesto        int,
  es_presidente boolean not null default false,
  presente      boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz,
  deleted_at    timestamptz
);
create index on public.catadores (cata_id);
create index on public.catadores (mesa_id, puesto);

-- ---------- MUESTRAS ----------
create table public.muestras (
  id              uuid primary key default gen_random_uuid(),
  cata_id         uuid not null references public.catas(id) on delete cascade,
  codigo          text not null,           -- código anónimo de la muestra
  nombre          text,
  bodega          text,
  categoria       text,
  tipo            text,                    -- tinto, blanco, rosado, espumoso...
  anada           int,
  pais            text,
  observaciones   text,
  medalla_manual  text check (medalla_manual in ('gran_oro','oro','plata','bronce','sin_medalla')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz,
  deleted_at      timestamptz
);
create unique index muestras_cata_codigo on public.muestras (cata_id, codigo) where deleted_at is null;

-- ---------- TANDAS ----------
create table public.tandas (
  id          uuid primary key default gen_random_uuid(),
  cata_id     uuid not null references public.catas(id) on delete cascade,
  mesa_id     uuid references public.mesas(id) on delete set null,
  nombre      text,
  orden       int not null default 0,
  estado      text not null default 'pendiente'
              check (estado in ('pendiente','en_curso','cerrada')),
  inicio_at   timestamptz,
  fin_at      timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz,
  deleted_at  timestamptz
);
create index on public.tandas (mesa_id, orden);

-- ---------- MUESTRAS DE CADA TANDA ----------
create table public.tanda_muestras (
  id          uuid primary key default gen_random_uuid(),
  cata_id     uuid not null references public.catas(id) on delete cascade,
  tanda_id    uuid not null references public.tandas(id) on delete cascade,
  muestra_id  uuid not null references public.muestras(id) on delete cascade,
  orden       int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz,
  deleted_at  timestamptz
);
create index on public.tanda_muestras (tanda_id, orden);

-- ---------- PUNTUACIONES ----------
create table public.puntuaciones (
  id          uuid primary key default gen_random_uuid(),
  cata_id     uuid not null references public.catas(id) on delete cascade,
  muestra_id  uuid not null references public.muestras(id) on delete cascade,
  catador_id  uuid not null references public.catadores(id) on delete cascade,
  tanda_id    uuid references public.tandas(id) on delete set null,
  puntos      numeric(5,2) check (puntos >= 0),
  detalle     jsonb not null default '{}'::jsonb,   -- vista, nariz, boca...
  comentario  text,
  anulada     boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz,
  deleted_at  timestamptz,
  unique (muestra_id, catador_id)
);
create index on public.puntuaciones (cata_id);

-- ---------- INCIDENCIAS ----------
create table public.incidencias (
  id           uuid primary key default gen_random_uuid(),
  cata_id      uuid not null references public.catas(id) on delete cascade,
  mesa_id      uuid references public.mesas(id) on delete set null,
  tanda_id     uuid references public.tandas(id) on delete set null,
  muestra_id   uuid references public.muestras(id) on delete set null,
  catador_id   uuid references public.catadores(id) on delete set null,
  tipo         text not null default 'otro'
               check (tipo in ('corcho','temperatura','muestra_defectuosa','botella_rota',
                               'catador_ausente','cambio_puesto','cambio_orden','error_puntuacion','otro')),
  prioridad    text not null default 'media' check (prioridad in ('baja','media','alta')),
  descripcion  text,
  estado       text not null default 'abierta' check (estado in ('abierta','resuelta')),
  resuelta_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz,
  deleted_at   timestamptz
);
create index on public.incidencias (cata_id, estado);

-- ---------- triggers updated_at + índice para sync ----------
do $$
declare t text;
begin
  foreach t in array array['catas','mesas','catadores','muestras','tandas',
                           'tanda_muestras','puntuaciones','incidencias'] loop
    execute format('create trigger touch_%1$s before insert or update on public.%1$s
                    for each row execute function public.tg_touch_updated_at()', t);
    execute format('create index %1$s_updated_at on public.%1$s (updated_at)', t);
  end loop;
end $$;

-- ---------- RESULTADOS / MEDALLAS (vista) ----------
create or replace view public.v_resultados
with (security_invoker = true) as
with p as (
  select pu.cata_id, pu.muestra_id, pu.puntos,
         row_number() over (partition by pu.muestra_id order by pu.puntos)      as rk_asc,
         row_number() over (partition by pu.muestra_id order by pu.puntos desc) as rk_desc,
         count(*)     over (partition by pu.muestra_id)                          as n
  from public.puntuaciones pu
  where pu.deleted_at is null and not pu.anulada and pu.puntos is not null
),
agg as (
  select p.muestra_id,
         count(*)                         as n_puntuaciones,
         round(avg(p.puntos), 2)          as media,
         round(avg(p.puntos) filter (where p.n < 5 or (p.rk_asc > 1 and p.rk_desc > 1)), 2) as media_sin_extremos,
         min(p.puntos)                    as minimo,
         max(p.puntos)                    as maximo
  from p group by p.muestra_id
)
select m.id as muestra_id, m.cata_id, m.codigo, m.nombre, m.bodega, m.categoria, m.tipo,
       coalesce(a.n_puntuaciones, 0) as n_puntuaciones,
       a.media, a.media_sin_extremos, a.minimo, a.maximo,
       case when c.descartar_extremos then a.media_sin_extremos else a.media end as nota_final,
       coalesce(m.medalla_manual,
         case
           when (case when c.descartar_extremos then a.media_sin_extremos else a.media end) is null then null
           when (case when c.descartar_extremos then a.media_sin_extremos else a.media end) >= c.umbral_gran_oro then 'gran_oro'
           when (case when c.descartar_extremos then a.media_sin_extremos else a.media end) >= c.umbral_oro then 'oro'
           when (case when c.descartar_extremos then a.media_sin_extremos else a.media end) >= c.umbral_plata then 'plata'
           when c.umbral_bronce is not null
            and (case when c.descartar_extremos then a.media_sin_extremos else a.media end) >= c.umbral_bronce then 'bronce'
           else 'sin_medalla'
         end) as medalla,
       m.medalla_manual is not null as medalla_es_manual
from public.muestras m
join public.catas c on c.id = m.cata_id
left join agg a on a.muestra_id = m.id
where m.deleted_at is null;

-- ---------- RPC: intercambiar puestos de dos catadores (atómico) ----------
create or replace function public.intercambiar_puestos(a uuid, b uuid)
returns void language plpgsql security invoker as $$
declare ma uuid; pa int; mb uuid; pb int;
begin
  select mesa_id, puesto into ma, pa from public.catadores where id = a for update;
  select mesa_id, puesto into mb, pb from public.catadores where id = b for update;
  update public.catadores set mesa_id = mb, puesto = pb where id = a;
  update public.catadores set mesa_id = ma, puesto = pa where id = b;
end $$;

-- ---------- RPC: reordenar tandas en bloque ----------
create or replace function public.reordenar(tabla text, ids uuid[])
returns void language plpgsql security invoker as $$
begin
  if tabla not in ('tandas','tanda_muestras') then
    raise exception 'tabla no permitida';
  end if;
  execute format(
    'update public.%I t set orden = x.ord - 1
       from unnest($1) with ordinality as x(id, ord)
      where t.id = x.id', tabla) using ids;
end $$;

-- ---------- RLS: solo usuarios autenticados ----------
do $$
declare t text;
begin
  foreach t in array array['catas','mesas','catadores','muestras','tandas',
                           'tanda_muestras','puntuaciones','incidencias'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "auth_all_%1$s" on public.%1$s for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- ---------- Realtime (actualización en vivo entre dispositivos) ----------
alter publication supabase_realtime add table
  public.catas, public.mesas, public.catadores, public.muestras, public.tandas,
  public.tanda_muestras, public.puntuaciones, public.incidencias;
