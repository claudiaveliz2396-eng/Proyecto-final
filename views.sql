-- ============================================================
-- VISTAS ANALITICAS DE CICLISTAPP
-- Ejecutar despues de DDLciclistapp.sql y seeds.sql
-- ============================================================


-- 1. Suscripciones e ingresos generados por cada plan.
create or replace view vw_ingresos_por_plan as
select
    pl.plan_id,
    pl.nombre as plan,
    pl.precio_mensual,
    count(distinct s.suscripcion_id) as total_suscripciones,
    count(distinct s.usuario_id) as usuarios_suscritos,
    count(p.pago_id) filter (
        where p.estado = 'pagado'
    ) as pagos_exitosos,
    coalesce(
        sum(p.monto) filter (
            where p.estado = 'pagado'
        ),
        0
    ) as ingresos_totales
from plan_suscripcion pl
left join suscripcion s
    on s.plan_id = pl.plan_id
left join pago p
    on p.suscripcion_id = s.suscripcion_id
group by
    pl.plan_id,
    pl.nombre,
    pl.precio_mensual;


-- 2. Uso, rendimiento y calificacion de cada ruta.
-- Las metricas se calculan por separado para evitar duplicar recorridos
-- cuando una ruta tiene varias calificaciones.
create or replace view vw_rendimiento_rutas as
with resumen_recorridos as (
    select
        ruta_id,
        count(*) as total_recorridos,
        count(distinct usuario_id) as usuarios_diferentes,
        avg(distancia_m) as distancia_promedio_m,
        avg(duracion_segundos) as duracion_promedio_segundos,
        avg(velocidad_promedio_kmh) as velocidad_promedio_kmh
    from recorrido
    where estado = 'completado'
    group by ruta_id
),
resumen_calificaciones as (
    select
        ruta_id,
        count(*) as total_calificaciones,
        avg(puntuacion) as calificacion_promedio
    from calificacion_ruta
    group by ruta_id
)
select
    r.ruta_id,
    r.nombre as ruta,
    u.nombre as creador,
    r.dificultad,
    r.distancia_m,
    coalesce(rr.total_recorridos, 0) as total_recorridos,
    coalesce(rr.usuarios_diferentes, 0) as usuarios_diferentes,
    round(rr.distancia_promedio_m, 2) as distancia_promedio_m,
    round(rr.duracion_promedio_segundos, 2) as duracion_promedio_segundos,
    round(rr.velocidad_promedio_kmh, 2) as velocidad_promedio_kmh,
    coalesce(rc.total_calificaciones, 0) as total_calificaciones,
    round(rc.calificacion_promedio, 2) as calificacion_promedio
from ruta r
left join usuario u
    on u.usuario_id = r.creada_por
left join resumen_recorridos rr
    on rr.ruta_id = r.ruta_id
left join resumen_calificaciones rc
    on rc.ruta_id = r.ruta_id;


-- 3. Estado y severidad de las incidencias por tramo de ciclovia.
create or replace view vw_incidencias_por_tramo as
select
    c.ciclovia_id,
    c.nombre as ciclovia,
    t.tramo_id,
    t.nombre as tramo,
    count(i.incidencia_id) as total_incidencias,
    count(i.incidencia_id) filter (
        where i.estado = 'reportada'
    ) as reportadas,
    count(i.incidencia_id) filter (
        where i.estado = 'en_revision'
    ) as en_revision,
    count(i.incidencia_id) filter (
        where i.estado = 'resuelta'
    ) as resueltas,
    count(i.incidencia_id) filter (
        where i.nivel in ('alta', 'critica')
    ) as incidencias_graves,
    max(i.reportada_en) as ultima_incidencia
from ciclovia c
join tramo_ciclovia t
    on t.ciclovia_id = c.ciclovia_id
left join incidencia i
    on i.tramo_id = t.tramo_id
group by
    c.ciclovia_id,
    c.nombre,
    t.tramo_id,
    t.nombre;


-- Comprobacion de las vistas creadas.
select table_name as vista
from information_schema.views
where table_schema = 'public'
  and table_name in (
      'vw_ingresos_por_plan',
      'vw_rendimiento_rutas',
      'vw_incidencias_por_tramo'
  )
order by table_name;
