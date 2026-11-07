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
