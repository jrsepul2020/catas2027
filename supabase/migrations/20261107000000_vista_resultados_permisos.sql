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
