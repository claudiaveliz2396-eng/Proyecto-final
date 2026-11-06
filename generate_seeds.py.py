"""Genera seeds.sql y seeds.json para CiclistApp sin conectarse a las bases."""

from __future__ import annotations

import bcrypt
import hashlib
import json
import random
import re
import unicodedata
from datetime import date, datetime, timedelta
from pathlib import Path

from faker import Faker


ROOT = Path(__file__).resolve().parents[2]
SQL_PATH = ROOT / "database" / "postgresql" / "seeds.sql"
JSON_PATH = ROOT / "database" / "mongodb" / "seeds.json"
NOW = datetime(2026, 11, 5, 12, 0)

random.seed(2026)
Faker.seed(2026)
fake = Faker("es_MX")


def slug(text):
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", ".", text.lower()).strip(".")


def sql_value(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, datetime):
        return f"'{value.isoformat(sep=' ')}'"
    if isinstance(value, date):
        return f"'{value.isoformat()}'"
    return "'" + str(value).replace("'", "''") + "'"


def insert_sql(table, columns, rows, batch=100):
    statements = []
    for start in range(0, len(rows), batch):
        values = [
            "(" + ", ".join(sql_value(v) for v in row) + ")"
            for row in rows[start:start + batch]
        ]
        statements.append(
            f"insert into {table} ({', '.join(columns)}) values\n    "
            + ",\n    ".join(values) + ";"
        )
    return "\n\n".join(statements)


def oid(number):
    return {"$oid": f"{number:024x}"}


def mdate(value):
    return {"$date": value.replace(microsecond=0).isoformat() + "Z"}


def point(lon, lat):
    return {"type": "Point", "coordinates": [round(lon, 6), round(lat, 6)]}


def unique_pairs(amount, left_max, right_max):
    pairs = set()
    while len(pairs) < amount:
        pairs.add((random.randint(1, left_max), random.randint(1, right_max)))
    return sorted(pairs)


def generate_users():
    users = []
    for user_id in range(1, 121):
        name = fake.name()
        key = slug(name)
        users.append({
            "id": user_id,
            "name": name,
            "email": f"{key}.{user_id}@ciclistapp.mx",
            "alias": f"{key.split('.')[0]}{user_id:03d}",
            "hash": bcrypt.hashpw(
                f"Ciclista_{user_id:03d}!".encode(), bcrypt.gensalt(10)
            ).decode(),
            "active": random.random() > 0.04,
            "created": NOW - timedelta(days=random.randint(30, 730)),
        })
    return users


def generate_sql(users):
    data = {}

    def add(table, columns, rows):
        data[table] = (columns, list(rows))

    add("usuario", ["usuario_id", "correo", "password_hash", "nombre", "alias", "activo", "creado_en"],
        ((u["id"], u["email"], u["hash"], u["name"], u["alias"], u["active"], u["created"].date()) for u in users))
    add("rol", ["rol_id", "nombre", "descripcion"], [
        (1, "administrador", "Control completo"), (2, "usuario_base", "Acceso general"),
        (3, "usuario_premium", "Funciones avanzadas"), (4, "moderador", "Revision de contenido")])
    add("usuario_rol", ["usuario_id", "rol_id", "asignado_por", "asignado_en"],
        ((u["id"], 1 if u["id"] <= 5 else 4 if u["id"] <= 10 else 3 if u["id"] <= 45 else 2, 1, u["created"]) for u in users))

    sessions = []
    for i in range(1, 181):
        created = NOW - timedelta(days=random.randint(0, 90))
        sessions.append((i, random.randint(1, 120), hashlib.sha256(f"session-{i}".encode()).hexdigest(),
                         fake.ipv4(), fake.user_agent(), created, created + timedelta(days=30), None))
    add("sesion_usuario", ["sesion_id", "usuario_id", "refresh_token_hash", "direccion_ip", "dispositivo", "creado_en", "expira_en", "revocada_en"], sessions)
    add("configuracion_seguridad", ["configuracion_id", "usuario_id", "verificacion_dos_pasos", "recibir_alertas_acceso", "actualizado_en"],
        ((i, i, random.random() < .35, True, NOW - timedelta(days=random.randint(0, 180))) for i in range(1, 121)))

    municipalities = ["Guadalajara", "Zapopan", "Tlaquepaque", "Tonala", "Tlajomulco", "El Salto", "Zapotlanejo", "Ixtlahuacan", "Juanacatlan", "Acatlan", "Amatitan", "Tequila", "Tala", "Etzatlan", "Ahualulco"]
    add("municipio", ["municipio_id", "nombre", "clave_inegi"],
        ((i, name, f"14{i:03d}") for i, name in enumerate(municipalities, 1)))
    add("colonia", ["colonia_id", "municipio_id", "nombre", "codigo_postal"],
        (((m - 1) * 3 + n, m, f"Colonia {municipalities[m - 1]} {n}", f"{44000 + (m - 1) * 3 + n:05d}")
         for m in range(1, 16) for n in range(1, 4)))
    add("ciclovia", ["ciclovia_id", "nombre", "descripcion", "fecha_alta", "activa"],
        ((i, f"Ciclovia Metropolitana {i}", fake.sentence(10), date(2022, 1, 1) + timedelta(days=i * 45), True) for i in range(1, 16)))

    stretches = []
    for i in range(1, 61):
        lat, lon = 20.60 + random.random() * .18, -103.45 + random.random() * .25
        stretches.append((i, (i - 1) // 4 + 1, f"Tramo {i}", lat, lon, lat + .004, lon + .004,
                          round(random.uniform(500, 4500), 2), random.choice(["norte", "sur", "oriente", "poniente", "doble"]), True))
    add("tramo_ciclovia", ["tramo_id", "ciclovia_id", "nombre", "latitud_inicio", "longitud_inicio", "latitud_fin", "longitud_fin", "longitud_m", "sentido", "activo"], stretches)
    add("tramo_colonia", ["tramo_id", "colonia_id", "es_principal"],
        ((i, (i - 1) % 45 + 1, True) for i in range(1, 61)))

    add("acciones_administrador", ["accion_id", "realizado_por", "entidad_afectada", "entidad_id", "realizado_en"],
        ((i, random.randint(1, 5), random.choice(["usuario", "ciclovia", "tramo", "incidencia", "ruta"]), random.randint(1, 120), NOW - timedelta(days=random.randint(0, 180))) for i in range(1, 151)))
    config_keys = ["velocidad_maxima", "radio_alertas", "dias_retencion", "correo_soporte", "mantenimiento", "version_mapa", "max_rutas", "max_favoritos", "umbral_incidencia", "notificaciones", "moneda", "zona_horaria", "idioma", "privacidad", "soporte"]
    add("configuracion_sistema", ["config_id", "clave", "valor", "actualizado_por", "actualizado_en"],
        ((i, key, str(random.randint(1, 100)), random.randint(1, 5), NOW - timedelta(days=i)) for i, key in enumerate(config_keys, 1)))
    add("reportes_admin", ["reporte_id", "creado_por", "titulo", "contenido", "creado_en"],
        ((i, random.randint(1, 5), f"Reporte {i}", fake.paragraph(4), NOW - timedelta(days=random.randint(0, 120))) for i in range(1, 31)))

    plans = ["Gratuito", "Urbano", "Explorador", "Ciclista Plus", "Ruta Pro", "Familiar", "Estudiante", "Empresarial", "Club Ciclista", "Turista", "Entrenamiento", "Competencia", "Movilidad", "Premium Anual", "Institucional"]
    plan_rows = [(i, name, f"Plan {name}", 0.0 if i == 1 else 49 + i * 20, 30 if i < 14 else 365, i >= 3, i >= 4, i >= 8, True) for i, name in enumerate(plans, 1)]
    add("plan_suscripcion", ["plan_id", "nombre", "descripcion", "precio_mensual", "duracion_dias", "rutas_personalizadas", "historial_avanzado", "soporte_prioritario", "activo"], plan_rows)
    subscriptions = []
    for i in range(1, 101):
        start = date(2026, 1, 1) + timedelta(days=random.randint(0, 250))
        subscriptions.append((i, i, random.randint(1, 15), start, start + timedelta(days=365), random.choice(["activa", "activa", "cancelada", "vencida", "pendiente"]), random.random() < .75))
    add("suscripcion", ["suscripcion_id", "usuario_id", "plan_id", "fecha_inicio", "fecha_fin", "estado", "renovacion_automatica"], subscriptions)
    methods = []
    for i in range(1, 101):
        kind = random.choice(["tarjeta", "paypal", "mercado_pago", "transferencia"])
        methods.append((i, i, kind, random.choice(["Visa", "Mastercard", "PayPal", "Mercado Pago", "SPEI"]),
                        f"{random.randint(0, 9999):04d}" if kind == "tarjeta" else None,
                        f"tok_{i:04d}_{hashlib.sha1(str(i).encode()).hexdigest()[:12]}", True, True, NOW - timedelta(days=random.randint(20, 500))))
    add("metodo_pago", ["metodo_pago_id", "usuario_id", "tipo", "proveedor", "ultimos_cuatro", "token_pago", "predeterminado", "activo", "creado_en"], methods)
    add("pago", ["pago_id", "suscripcion_id", "metodo_pago_id", "monto", "fecha_pago", "estado", "referencia"],
        ((i, sid := random.randint(1, 100), sid, plan_rows[subscriptions[sid - 1][2] - 1][3], NOW - timedelta(days=random.randint(0, 300)), random.choice(["pagado", "pagado", "pendiente", "rechazado", "reembolsado"]), f"PAGO-2026-{i:06d}") for i in range(1, 181)))

    bike_types = ["urbana", "montaña", "ruta", "electrica", "plegable", "hibrida", "otra"]
    add("bicicleta", ["bicicleta_id", "usuario_id", "nombre", "tipo", "marca", "modelo", "rodada", "activa", "creada_en"],
        ((i, i, f"Bicicleta de {users[i - 1]['alias']}", random.choice(bike_types), random.choice(["Trek", "Giant", "Benotto"]), f"Modelo {random.randint(1, 20)}", random.choice(["26", "27.5", "29", "700c"]), True, users[i - 1]["created"]) for i in range(1, 121)))
    routes = []
    for i in range(1, 101):
        lat, lon = 20.60 + random.random() * .18, -103.45 + random.random() * .25
        routes.append((i, random.randint(1, 120), f"Ruta {i}", fake.sentence(12), lat, lon, lat + .02, lon + .02,
                       round(random.uniform(1500, 45000), 2), random.randint(10, 180), random.choice(["facil", "media", "dificil"]), random.random() < .8, True, NOW - timedelta(days=random.randint(0, 500))))
    add("ruta", ["ruta_id", "creada_por", "nombre", "descripcion", "latitud_inicio", "longitud_inicio", "latitud_fin", "longitud_fin", "distancia_m", "duracion_estimada_min", "dificultad", "publica", "activa", "creada_en"], routes)
    add("ruta_tramo", ["ruta_id", "tramo_id", "orden"],
        ((r, stretch, order) for r in range(1, 101) for order, stretch in enumerate(random.sample(range(1, 61), 3 if r <= 50 else 2), 1)))
    add("ruta_favorita", ["usuario_id", "ruta_id", "guardada_en"],
        ((u, r, NOW - timedelta(days=random.randint(0, 180))) for u, r in unique_pairs(150, 120, 100)))

    rides = []
    for i in range(1, 201):
        user = random.randint(1, 120); start = NOW - timedelta(days=random.randint(0, 365)); duration = random.randint(600, 10800)
        state = random.choice(["completado", "completado", "cancelado", "en_progreso"]); end = start + timedelta(seconds=duration) if state != "en_progreso" else None
        rides.append((i, user, user, random.randint(1, 100), start, end, round(random.uniform(1000, 60000), 2), duration if end else None, round(random.uniform(8, 28), 2), round(random.uniform(25, 55), 2), state))
    add("recorrido", ["recorrido_id", "usuario_id", "bicicleta_id", "ruta_id", "inicio", "fin", "distancia_m", "duracion_segundos", "velocidad_promedio_kmh", "velocidad_maxima_kmh", "estado"], rides)
    ride_points = []
    for ride in rides:
        lat, lon = 20.62 + random.random() * .12, -103.42 + random.random() * .20
        for step in range(5):
            ride_points.append((len(ride_points) + 1, ride[0], lat + step * .001, lon + step * .001, round(random.uniform(1500, 1700), 2), round(random.uniform(5, 35), 2), ride[4] + timedelta(minutes=step * 3)))
    add("recorrido_punto", ["punto_id", "recorrido_id", "latitud", "longitud", "altitud_m", "velocidad_kmh", "registrado_en"], ride_points)

    issue_types = ["bache", "accidente", "obra", "bloqueo", "inseguridad", "inundacion", "semaforo", "otro"]
    issues = []
    for i in range(1, 151):
        reported = NOW - timedelta(days=random.randint(0, 240)); state = random.choice(["reportada", "en_revision", "resuelta", "descartada"])
        issues.append((i, random.randint(1, 120), random.randint(1, 60), random.choice(issue_types), fake.sentence(14), 20.60 + random.random() * .18, -103.45 + random.random() * .25, random.choice(["baja", "media", "alta", "critica"]), state, reported, reported + timedelta(days=random.randint(1, 10)) if state == "resuelta" else None))
    add("incidencia", ["incidencia_id", "usuario_id", "tramo_id", "tipo", "descripcion", "latitud", "longitud", "nivel", "estado", "reportada_en", "resuelta_en"], issues)
    add("calificacion_ruta", ["calificacion_id", "usuario_id", "ruta_id", "puntuacion", "comentario", "creada_en"],
        ((i, u, r, random.randint(1, 5), fake.sentence(10), NOW - timedelta(days=random.randint(0, 300))) for i, (u, r) in enumerate(unique_pairs(250, 120, 100), 1)))

    poi_types = ["taller", "estacion_bicicletas", "estacionamiento", "tienda", "agua", "hospital", "parque", "otro"]
    poi = [(i, f"Punto de interes {i}", "estacion_bicicletas" if i <= 15 else random.choice(poi_types), fake.sentence(8), 20.60 + random.random() * .18, -103.45 + random.random() * .25, fake.address().replace("\n", ", "), True) for i in range(1, 61)]
    add("punto_interes", ["punto_interes_id", "nombre", "tipo", "descripcion", "latitud", "longitud", "direccion", "activo"], poi)
    add("ruta_punto_interes", ["ruta_id", "punto_interes_id", "orden"],
        ((r, p, index % 4 + 1) for index, (r, p) in enumerate(unique_pairs(180, 100, 60))))
    stations = []
    for i in range(1, 16):
        capacity = random.randint(12, 40); bikes = random.randint(0, capacity)
        stations.append((i, i, capacity, bikes, capacity - bikes, "06:00", "22:00", random.choice(["activa", "activa", "mantenimiento", "inactiva"]), NOW))
    add("estacion_bicicleta", ["estacion_id", "punto_interes_id", "capacidad", "bicicletas_disponibles", "espacios_disponibles", "horario_apertura", "horario_cierre", "estado", "actualizada_en"], stations)

    transitions = [(None, "reportada"), ("reportada", "en_revision"), ("en_revision", "resuelta"), ("en_revision", "descartada")]
    history = []
    for i in range(1, 251):
        old, new = random.choice(transitions)
        history.append((i, random.randint(1, 150), random.randint(1, 10), old, new, fake.sentence(8), NOW - timedelta(days=random.randint(0, 240))))
    add("historial_estado_incidencia", ["historial_id", "incidencia_id", "cambiado_por", "estado_anterior", "estado_nuevo", "comentario", "cambiado_en"], history)
    notices = []
    for i in range(1, 301):
        kind = random.choice(["incidencia", "ruta", "pago", "suscripcion", "sistema"]); created = NOW - timedelta(days=random.randint(0, 180)); read = random.random() < .65
        notices.append((i, random.randint(1, 120), random.randint(1, 150) if kind == "incidencia" else None, random.randint(1, 100) if kind == "ruta" else None, random.randint(1, 180) if kind == "pago" else None, random.randint(1, 100) if kind == "suscripcion" else None, kind, f"Aviso de {kind}", fake.sentence(12), read, created, created + timedelta(hours=random.randint(1, 72)) if read else None))
    add("notificacion", ["notificacion_id", "usuario_id", "incidencia_id", "ruta_id", "pago_id", "suscripcion_id", "tipo", "titulo", "mensaje", "leida", "creada_en", "leida_en"], notices)

    order = ["usuario", "rol", "usuario_rol", "sesion_usuario", "configuracion_seguridad", "municipio", "colonia", "ciclovia", "tramo_ciclovia", "tramo_colonia", "acciones_administrador", "configuracion_sistema", "reportes_admin", "plan_suscripcion", "suscripcion", "metodo_pago", "pago", "bicicleta", "ruta", "ruta_tramo", "ruta_favorita", "recorrido", "recorrido_punto", "incidencia", "calificacion_ruta", "punto_interes", "ruta_punto_interes", "estacion_bicicleta", "historial_estado_incidencia", "notificacion"]
    parts = ["-- Generado automaticamente por script_poblar_mongo.py", "-- Ejecutar despues de DDLciclistapp.sql sobre una base vacia.", "begin;"]
    for table in order:
        parts.append(insert_sql(table, *data[table]))
    sequence_columns = {"usuario": "usuario_id", "rol": "rol_id", "sesion_usuario": "sesion_id", "configuracion_seguridad": "configuracion_id", "municipio": "municipio_id", "colonia": "colonia_id", "ciclovia": "ciclovia_id", "tramo_ciclovia": "tramo_id", "acciones_administrador": "accion_id", "configuracion_sistema": "config_id", "reportes_admin": "reporte_id", "plan_suscripcion": "plan_id", "suscripcion": "suscripcion_id", "metodo_pago": "metodo_pago_id", "pago": "pago_id", "bicicleta": "bicicleta_id", "ruta": "ruta_id", "recorrido": "recorrido_id", "recorrido_punto": "punto_id", "incidencia": "incidencia_id", "calificacion_ruta": "calificacion_id", "punto_interes": "punto_interes_id", "estacion_bicicleta": "estacion_id", "historial_estado_incidencia": "historial_id", "notificacion": "notificacion_id"}
    for table, column in sequence_columns.items():
        parts.append(f"select setval(pg_get_serial_sequence('{table}', '{column}'), (select max({column}) from {table}), true);")
    parts.append("commit;")
    SQL_PATH.parent.mkdir(parents=True, exist_ok=True)
    SQL_PATH.write_text("\n\n".join(parts) + "\n", encoding="utf-8")
    return len(data), sum(len(rows) for _, rows in data.values())


def generate_mongo(users):
    user_ids = [oid(100000 + i) for i in range(1, 121)]; route_ids = [oid(200000 + i) for i in range(1, 101)]
    stretch_ids = [oid(300000 + i) for i in range(1, 61)]; poi_ids = [oid(400000 + i) for i in range(1, 61)]
    bike_ids = [oid(500000 + i) for i in range(1, 121)]; issue_ids = [oid(600000 + i) for i in range(1, 151)]
    subscription_ids = [oid(700000 + i) for i in range(1, 101)]
    bike_types = ["urbana", "montaña", "ruta", "electrica", "plegable", "hibrida", "otra"]
    mongo_users = [{"_id": user_ids[i], "correo": u["email"], "password_hash": u["hash"], "nombre": u["name"], "alias": u["alias"], "activo": u["active"], "creado_en": mdate(u["created"]),
        "roles": ["administrador" if i < 5 else "moderador" if i < 10 else "usuario_premium" if i < 45 else "usuario_base"],
        "configuracion_seguridad": {"verificacion_dos_pasos": random.random() < .35, "recibir_alertas_acceso": True, "actualizado_en": mdate(NOW)},
        "sesiones": [{"refresh_token_hash": hashlib.sha256(f"mongo-{i}".encode()).hexdigest(), "direccion_ip": fake.ipv4(), "dispositivo": fake.user_agent(), "creado_en": mdate(NOW - timedelta(days=random.randint(0, 20))), "expira_en": mdate(NOW + timedelta(days=30)), "revocada_en": None}],
        "metodos_pago": [{"tipo": "tarjeta", "proveedor": random.choice(["Visa", "Mastercard"]), "ultimos_cuatro": f"{random.randint(0, 9999):04d}", "token_pago": f"mongo_tok_{i + 1:04d}", "predeterminado": True, "activo": True}],
        "bicicletas": [{"bicicleta_id": bike_ids[i], "nombre": f"Bicicleta de {u['alias']}", "tipo": random.choice(bike_types), "marca": random.choice(["Trek", "Giant", "Benotto"]), "modelo": f"Modelo {random.randint(1, 20)}", "rodada": random.choice(["26", "27.5", "29", "700c"]), "activa": True}], "rutas_favoritas": random.sample(route_ids, 3)} for i, u in enumerate(users)]

    cycling = []
    for c in range(15):
        stretches = []
        for j in range(4):
            index = c * 4 + j; lat, lon = 20.60 + random.random() * .18, -103.45 + random.random() * .25
            stretches.append({"tramo_id": stretch_ids[index], "nombre": f"Tramo {index + 1}", "ubicacion_inicio": point(lon, lat), "ubicacion_fin": point(lon + .004, lat + .004), "longitud_m": round(random.uniform(500, 4500), 2), "sentido": random.choice(["norte", "sur", "oriente", "poniente", "doble"]), "activo": True, "colonias_asociadas": [{"nombre_colonia": f"Colonia {index + 1}", "codigo_postal": f"{44000 + index:05d}", "municipio": random.choice(["Guadalajara", "Zapopan", "Tlaquepaque"]), "clave_inegi": f"14{random.randint(1, 15):03d}", "es_principal": True}]})
        cycling.append({"_id": oid(800000 + c + 1), "nombre": f"Ciclovia {c + 1}", "descripcion": fake.sentence(10), "fecha_alta": mdate(datetime(2022, 1, 1) + timedelta(days=c * 45)), "activa": True, "tramos": stretches})

    poi_types = ["taller", "estacion_bicicletas", "estacionamiento", "tienda", "agua", "hospital", "parque", "otro"]
    pois = []
    for i in range(60):
        kind = "estacion_bicicletas" if i < 15 else random.choice(poi_types); lat, lon = 20.60 + random.random() * .18, -103.45 + random.random() * .25
        doc = {"_id": poi_ids[i], "nombre": f"Punto {i + 1}", "tipo": kind, "descripcion": fake.sentence(8), "ubicacion": point(lon, lat), "direccion": fake.address().replace("\n", ", "), "activo": True}
        if kind == "estacion_bicicletas":
            cap = random.randint(12, 40); available = random.randint(0, cap)
            doc["detalles_estacion"] = {"capacidad": cap, "bicicletas_disponibles": available, "espacios_disponibles": cap - available, "horario_apertura": "06:00", "horario_cierre": "22:00", "estado": "activa", "actualizada_en": mdate(NOW)}
        pois.append(doc)

    routes = []
    for i in range(100):
        lat, lon = 20.60 + random.random() * .18, -103.45 + random.random() * .25
        routes.append({"_id": route_ids[i], "creada_por": random.choice(user_ids), "nombre": f"Ruta {i + 1}", "descripcion": fake.sentence(12), "ubicacion_inicio": point(lon, lat), "ubicacion_fin": point(lon + .02, lat + .02), "distancia_m": round(random.uniform(1500, 45000), 2), "duracion_estimada_min": random.randint(10, 180), "dificultad": random.choice(["facil", "media", "dificil"]), "publica": random.random() < .8, "activa": True, "creada_en": mdate(NOW - timedelta(days=random.randint(0, 500))), "tramos_secuencia": [{"tramo_id": x, "orden": n} for n, x in enumerate(random.sample(stretch_ids, 3), 1)], "puntos_interes_secuencia": [{"punto_interes_id": x, "orden": n} for n, x in enumerate(random.sample(poi_ids, 3), 1)], "calificaciones": [{"usuario_id": random.choice(user_ids), "puntuacion": random.randint(1, 5), "comentario": fake.sentence(10), "creada_en": mdate(NOW)}]})

    rides = []
    for i in range(200):
        user = random.randrange(120); start = NOW - timedelta(days=random.randint(0, 365)); duration = random.randint(600, 10800); lat, lon = 20.60 + random.random() * .18, -103.45 + random.random() * .25
        rides.append({"_id": oid(900000 + i + 1), "usuario_id": user_ids[user], "bicicleta_id": bike_ids[user], "ruta_id": random.choice(route_ids), "inicio": mdate(start), "fin": mdate(start + timedelta(seconds=duration)), "distancia_m": round(random.uniform(1000, 60000), 2), "duracion_segundos": duration, "velocidad_promedio_kmh": round(random.uniform(8, 28), 2), "velocidad_maxima_kmh": round(random.uniform(25, 55), 2), "estado": "completado", "puntos_gps": [{"coordenadas": point(lon + s * .001, lat + s * .001), "altitud_m": round(random.uniform(1500, 1700), 2), "velocidad_kmh": round(random.uniform(5, 35), 2), "registrado_en": mdate(start + timedelta(minutes=s * 3))} for s in range(10)]})

    issue_types = ["bache", "accidente", "obra", "bloqueo", "inseguridad", "inundacion", "semaforo", "otro"]
    issues = []
    for i in range(150):
        reported = NOW - timedelta(days=random.randint(0, 240)); state = random.choice(["reportada", "en_revision", "resuelta", "descartada"]); lat, lon = 20.60 + random.random() * .18, -103.45 + random.random() * .25
        issues.append({"_id": issue_ids[i], "usuario_id": random.choice(user_ids), "tramo_id": random.choice(stretch_ids), "tipo": random.choice(issue_types), "descripcion": fake.sentence(14), "ubicacion": point(lon, lat), "nivel": random.choice(["baja", "media", "alta", "critica"]), "estado": state, "reportada_en": mdate(reported), "resuelta_en": mdate(reported + timedelta(days=2)) if state == "resuelta" else None, "historial_estados": [{"cambiado_por": random.choice(user_ids[:10]), "estado_anterior": "reportada", "estado_nuevo": "en_revision" if state != "reportada" else "reportada", "comentario": fake.sentence(8), "cambiado_en": mdate(reported + timedelta(hours=4))}]})

    plans = ["Gratuito", "Urbano", "Explorador", "Ciclista Plus", "Ruta Pro", "Familiar", "Estudiante", "Empresarial", "Club Ciclista", "Turista", "Entrenamiento", "Competencia", "Movilidad", "Premium Anual", "Institucional"]
    plan_ids = [oid(1100000 + i) for i in range(1, 16)]; subscriptions = []
    for i in range(100):
        p = random.randrange(15); start = NOW - timedelta(days=random.randint(0, 300)); price = 0.0 if p == 0 else float(49 + (p + 1) * 20)
        subscriptions.append({"_id": subscription_ids[i], "usuario_id": user_ids[i], "plan": {"plan_id": plan_ids[p], "nombre": plans[p], "precio_mensual": price, "duracion_dias": 30 if p < 13 else 365, "rutas_personalizadas": p >= 2, "historial_avanzado": p >= 3, "soporte_prioritario": p >= 7}, "fecha_inicio": mdate(start), "fecha_fin": mdate(start + timedelta(days=365)), "estado": random.choice(["activa", "activa", "cancelada", "vencida", "pendiente"]), "renovacion_automatica": random.random() < .75, "historial_pagos": [{"metodo_pago_token": f"mongo_tok_{i + 1:04d}", "monto": price, "fecha_pago": mdate(start), "estado": "pagado", "referencia": f"MONGO-PAGO-{i + 1:06d}"}]})

    notices = []
    for i in range(300):
        kind = random.choice(["incidencia", "ruta", "pago", "suscripcion", "sistema"]); created = NOW - timedelta(days=random.randint(0, 180)); read = random.random() < .65
        ref = random.choice(issue_ids) if kind == "incidencia" else random.choice(route_ids) if kind == "ruta" else random.choice(subscription_ids) if kind == "suscripcion" else oid(1200000 + i + 1)
        notices.append({"_id": oid(1300000 + i + 1), "usuario_id": random.choice(user_ids), "referencia_origen_id": ref, "tipo": kind, "titulo": f"Aviso de {kind}", "mensaje": fake.sentence(12), "leida": read, "creada_en": mdate(created), "leida_en": mdate(created + timedelta(hours=2)) if read else None})

    admin = [{"_id": oid(1400000 + i), "tipo": "log_accion", "realizado_por": random.choice(user_ids[:10]), "entidad": random.choice(["usuario", "ruta", "incidencia", "ciclovia"]), "entidad_id": random.choice(user_ids), "accion": random.choice(["alta", "modificacion", "revision", "baja_logica"]), "detalle": fake.sentence(12), "fecha": mdate(NOW - timedelta(days=random.randint(0, 180)))} for i in range(1, 151)]
    admin += [{"_id": oid(1500000 + i), "tipo": "configuracion", "clave": f"config_{i}", "valor": random.randint(1, 100), "actualizado_por": random.choice(user_ids[:5]), "actualizado_en": mdate(NOW)} for i in range(1, 16)]
    admin += [{"_id": oid(1600000 + i), "tipo": "reporte", "creado_por": random.choice(user_ids[:5]), "titulo": f"Reporte {i}", "contenido": fake.paragraph(4), "creado_en": mdate(NOW - timedelta(days=random.randint(0, 120)))} for i in range(1, 31)]

    collections = {"usuarios": mongo_users, "ciclovias": cycling, "rutas": routes, "recorridos": rides, "incidencias": issues, "suscripciones": subscriptions, "puntos_interes": pois, "notificaciones": notices, "administracion": admin}
    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(collections, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return len(collections), sum(len(docs) for docs in collections.values())


def main():
    users = generate_users()
    sql_tables, sql_rows = generate_sql(users)
    mongo_collections, mongo_docs = generate_mongo(users)
    print("Datos semilla generados correctamente")
    print(f"SQL:  {SQL_PATH} ({sql_tables} tablas, {sql_rows} filas)")
    print(f"JSON: {JSON_PATH} ({mongo_collections} colecciones, {mongo_docs} documentos)")


if __name__ == "__main__":
    main()
