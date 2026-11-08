-- LOCAL no baja dias_concurso: tandas y registro_cambios guardan dia_id
-- como referencia lógica (sync_estado.dia_id), sin FK a la tabla de días.

alter table public.tandas drop constraint if exists tandas_dia_id_fkey;
alter table public.registro_cambios drop constraint if exists registro_cambios_dia_id_fkey;
-- sync_estado ya se soltó en 20261108200000; por si falta en algún LOCAL:
alter table public.sync_estado drop constraint if exists sync_estado_dia_id_fkey;
