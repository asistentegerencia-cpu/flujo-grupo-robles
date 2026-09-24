-- PASO 8 (ya aplicado en Supabase el 2026-09-24 como migración "reparto_fijos_y_tc_mensual").
-- Reparto de costos fijos: lista de áreas separadas por coma. Vacío = todas las áreas principales menos DEUDA GG.
alter table movimientos add column if not exists reparto text;
-- Tipo de cambio editable por mes (vacío = valor por defecto del código).
alter table saldos add column if not exists tc numeric;
