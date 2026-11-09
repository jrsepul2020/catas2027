-- Nota de observaciones del admin en cada muestra (aditiva).
alter table public.muestras add column if not exists observaciones text;
