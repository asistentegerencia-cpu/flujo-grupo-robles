-- PASO 10 (ya aplicado en Supabase el 2026-09-24 como migración "fijos_bases_colaboradores").
-- Cuadro de colaboradores por área para repartir los costos fijos.
-- Una fila por mes desde el que rige el cuadro; se usa en los meses siguientes hasta que se guarde otro.
-- grupos = [{k, l (nombre), n (colaboradores), areas (áreas de la distribución donde se suma)}]
create table if not exists fijos_bases (
  ym text primary key,
  grupos jsonb not null,
  actualizado timestamptz not null default now()
);

alter table fijos_bases enable row level security;

drop policy if exists "fijos_bases select" on fijos_bases;
create policy "fijos_bases select" on fijos_bases
  for select to authenticated using (true);

drop policy if exists "fijos_bases editor all" on fijos_bases;
create policy "fijos_bases editor all" on fijos_bases
  for all to authenticated
  using (exists (select 1 from perfiles where id = auth.uid() and rol = 'editor'))
  with check (exists (select 1 from perfiles where id = auth.uid() and rol = 'editor'));

insert into fijos_bases (ym, grupos) values ('2026-01', '[
  {"k":"VYM","l":"Ventas y Mkt","n":14,"areas":["VENTAS","MKT"]},
  {"k":"COMEX","l":"Comex","n":2,"areas":["OPE Comex"]},
  {"k":"ADM","l":"ADM","n":6,"areas":["ADM"]},
  {"k":"EVOLUTION","l":"Evolution","n":3,"areas":["EVOLUTION"]}
]'::jsonb)
on conflict (ym) do nothing;
