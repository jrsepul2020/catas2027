-- Datos de demostración para Supabase LOCAL (supabase db reset)
insert into public.catas (id, nombre, fecha, lugar)
values ('00000000-0000-0000-0000-000000002027', 'Catas Virtus 2027', '2027-03-15', 'Sede principal');

insert into public.mesas (id, cata_id, numero, nombre)
select ('00000000-0000-0000-0001-' || lpad(n::text, 12, '0'))::uuid,
       '00000000-0000-0000-0000-000000002027', n, 'Mesa ' || n
from generate_series(1, 4) n;

insert into public.catadores (cata_id, nombre, apellidos, mesa_id, puesto, es_presidente)
select '00000000-0000-0000-0000-000000002027',
       (array['Ana','Luis','Marta','Jorge','Elena','Pablo','Sara','Iván','Lucía','Raúl',
              'Carmen','Diego','Nuria','Óscar','Rosa','Hugo','Irene','Mario','Alba','Teo'])[i],
       'Catador ' || i,
       ('00000000-0000-0000-0001-' || lpad((((i - 1) / 5) + 1)::text, 12, '0'))::uuid,
       ((i - 1) % 5) + 1,
       ((i - 1) % 5) = 0
from generate_series(1, 20) i;

insert into public.muestras (cata_id, codigo, nombre, bodega, categoria, tipo, anada)
select '00000000-0000-0000-0000-000000002027',
       'M' || lpad(i::text, 3, '0'),
       'Vino ' || i, 'Bodega ' || ((i % 7) + 1),
       (array['Tinto joven','Tinto crianza','Blanco','Rosado','Espumoso'])[(i % 5) + 1],
       (array['tinto','tinto','blanco','rosado','espumoso'])[(i % 5) + 1],
       2022 + (i % 4)
from generate_series(1, 48) i;

-- 3 tandas por mesa con 4 muestras cada una
insert into public.tandas (id, cata_id, mesa_id, nombre, orden)
select ('00000000-0000-0000-0002-' || lpad(((m - 1) * 3 + t)::text, 12, '0'))::uuid,
       '00000000-0000-0000-0000-000000002027',
       ('00000000-0000-0000-0001-' || lpad(m::text, 12, '0'))::uuid,
       'Tanda ' || t, t - 1
from generate_series(1, 4) m, generate_series(1, 3) t;

insert into public.tanda_muestras (cata_id, tanda_id, muestra_id, orden)
select '00000000-0000-0000-0000-000000002027', ('00000000-0000-0000-0002-' || lpad((((x.rn - 1) / 4) + 1)::text, 12, '0'))::uuid,
       x.id, (x.rn - 1) % 4
from (select id, row_number() over (order by codigo) rn from public.muestras) x;
