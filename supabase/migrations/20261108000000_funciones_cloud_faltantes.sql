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

-- Event trigger real en Cloud: ensure_rls (la función se llama rls_auto_enable).
-- Limpia también el nombre erróneo de un borrador anterior de esta migración.
drop event trigger if exists rls_auto_enable;
drop event trigger if exists ensure_rls;
create event trigger ensure_rls
  on ddl_command_end
  execute function public.rls_auto_enable();

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
