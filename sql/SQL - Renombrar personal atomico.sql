-- PASO 9 (ya aplicado en Supabase el 2026-09-24 como migración "renombrar_personal_atomico").
-- Renombra a una persona del Personal y arrastra su nombre en movimientos y metas, todo en una sola transacción.
-- security invoker: se aplican las políticas RLS del usuario que la llama (solo editores pueden escribir).
create or replace function public.renombrar_personal(p_id uuid, p_nombre text)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_viejo text;
  v_nuevo text := btrim(p_nombre);
begin
  if not exists (select 1 from perfiles where id = auth.uid() and rol = 'editor') then
    raise exception 'Solo un editor puede renombrar personal';
  end if;
  if v_nuevo is null or v_nuevo = '' then
    raise exception 'El nombre no puede quedar vacío';
  end if;
  select nombre into v_viejo from asesores where id = p_id;
  if v_viejo is null then
    raise exception 'No se encontró a esa persona';
  end if;
  if v_viejo = v_nuevo then
    return;
  end if;
  update asesores set nombre = v_nuevo where id = p_id;
  update movimientos set asesor = v_nuevo where asesor = v_viejo;
  update movimientos set personal = v_nuevo where personal = v_viejo;
  update metas_personal set nombre = v_nuevo where nombre = v_viejo;
end;
$$;

revoke all on function public.renombrar_personal(uuid, text) from public, anon;
grant execute on function public.renombrar_personal(uuid, text) to authenticated;
