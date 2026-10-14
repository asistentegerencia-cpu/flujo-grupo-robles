-- Conciliación de ingresos: banco (fuente del dinero) vs Evolta (contrato / cuota)
-- Tablas nuevas; no modifica las existentes.

-- Pagos registrados en Evolta (Reporte de Cobranza), agrupados por operación
create table if not exists public.evolta_pagos(
  k text primary key,                 -- OC|Etapa|Lote|FechaPago|N° operación
  fecha date not null,
  monto numeric(14,2) not null,
  oc text, etapa text, lote text, titular text, doc text,
  tipos text,                         -- "CUOTA INICIAL 3, FINANCIAMIENTO 4"
  prog text,                          -- meses programados de esas cuotas
  medio text, tc numeric, verificado text, nro_op text, asesor text, financiamiento text,
  rev_estado text not null default '',-- revisión cuando no aparece en el banco
  rev_nota text not null default '',
  updated_at timestamptz not null default now()
);
create index if not exists evolta_pagos_fecha on public.evolta_pagos(fecha);

-- Ventas (Reporte de Ventas de Evolta): para m², precio y estado del lote
create table if not exists public.evolta_ventas(
  id text primary key,                -- IdProforma (el N° de OC se repite entre años)
  oc text, fecha_venta date, estado_oc text, fecha_dev date,
  etapa text, lote text, lote2 text, titular text, doc text,
  m2 numeric, precio numeric, tipo_fin text, vendedor text, moneda text,
  updated_at timestamptz not null default now()
);

-- A qué cliente / lote / cuota pertenece cada ingreso del banco
create table if not exists public.conciliacion(
  sig text primary key references public.movimientos(sig) on delete cascade,
  tipo text not null check (tipo in ('evolta','manual','desistido','interno','otro')),
  pagos text[] not null default '{}', -- claves de evolta_pagos
  cliente text not null default '',
  lote text not null default '',
  nota text not null default '',
  metodo text not null default '',    -- 'auto: …' o 'manual'
  usuario text not null default '',
  updated_at timestamptz not null default now()
);

-- Historial de cambios (para exportarlo después)
create table if not exists public.conciliacion_log(
  id bigserial primary key,
  at timestamptz not null default now(),
  usuario text, tabla text, clave text, accion text,
  antes jsonb, despues jsonb
);

alter table public.evolta_pagos enable row level security;
alter table public.evolta_ventas enable row level security;
alter table public.conciliacion enable row level security;
alter table public.conciliacion_log enable row level security;

create policy "evolta_pagos select" on public.evolta_pagos for select to authenticated using (true);
create policy "evolta_pagos editor all" on public.evolta_pagos for all to authenticated
  using (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'))
  with check (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'));
create policy "evolta_ventas select" on public.evolta_ventas for select to authenticated using (true);
create policy "evolta_ventas editor all" on public.evolta_ventas for all to authenticated
  using (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'))
  with check (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'));
create policy "conciliacion select" on public.conciliacion for select to authenticated using (true);
create policy "conciliacion editor all" on public.conciliacion for all to authenticated
  using (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'))
  with check (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'));
create policy "conciliacion_log select" on public.conciliacion_log for select to authenticated using (true);
create policy "conciliacion_log editor all" on public.conciliacion_log for all to authenticated
  using (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'))
  with check (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'));

-- Contratos (Reporte de Flujo de Caja de Evolta): precio, inicial, saldo a financiar, separaciones sin venta
create table if not exists public.evolta_contratos(
  id text primary key,                -- ETAPA|LOTE1|DOC
  etapa text, lotes text, titular text, doc text,
  fecha_sep date, fecha_venta date, precio numeric, ci_total numeric, ci_cobrada numeric,
  sf_total numeric, sf_cobrada numeric, pagado numeric, saldo numeric,
  tipo_fin text, vendedor text, moneda text, updated_at timestamptz not null default now()
);
-- Stock de lotes (Reporte de Stock de Inmuebles): m², precio y estado de cada lote
create table if not exists public.evolta_stock(
  id text primary key,                -- ETAPA|LOTE
  etapa text, lote text, estado text, m2 numeric, precio numeric, lista numeric, moneda text,
  updated_at timestamptz not null default now()
);
alter table public.evolta_contratos enable row level security;
alter table public.evolta_stock enable row level security;
create policy "evolta_contratos select" on public.evolta_contratos for select to authenticated using (true);
create policy "evolta_contratos editor all" on public.evolta_contratos for all to authenticated
  using (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'))
  with check (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'));
create policy "evolta_stock select" on public.evolta_stock for select to authenticated using (true);
create policy "evolta_stock editor all" on public.evolta_stock for all to authenticated
  using (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'))
  with check (exists (select 1 from public.perfiles where perfiles.id = auth.uid() and perfiles.rol = 'editor'));

-- Inicial pactada (separación + cuota inicial) y monto a financiar de cada OC, del Reporte de Ventas
alter table public.evolta_ventas add column if not exists inicial numeric, add column if not exists financiar numeric;

-- Cambio de moneda (compra/venta de dólares): área que lo pidió y grupo que une la salida, la entrada y los pagos hechos con esa moneda
alter table public.movimientos add column if not exists cambio_area text, add column if not exists cambio_grupo text;
