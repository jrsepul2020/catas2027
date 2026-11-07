-- resolver_incidencia y reordenar_muestras usan funciones internas del sistema
-- (recatar_muestra, pasar_al_final, quitar_de_tanda, _renumerar_tanda) que
-- solo puede ejecutar el propietario. En vez de abrir esas funciones, estas dos
-- se ejecutan como propietario y solo las pueden llamar usuarios autenticados.
alter function public.resolver_incidencia(integer, text, text) security definer;
alter function public.reordenar_muestras(integer, integer[], text) security definer;
revoke execute on function public.resolver_incidencia(integer, text, text) from public, anon;
revoke execute on function public.reordenar_muestras(integer, integer[], text) from public, anon;
grant execute on function public.resolver_incidencia(integer, text, text) to authenticated;
grant execute on function public.reordenar_muestras(integer, integer[], text) to authenticated;
