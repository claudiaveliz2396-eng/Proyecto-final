-- =====================================================
-- tablas de usuarios - ciclistapp
-- =====================================================


-- 1. usuarios
create table usuario (
    usuario_id SERIAL primary key,
    correo varchar(255) not null unique,
    password_hash varchar(255) not null,
    nombre varchar(120) not null,
    alias varchar(60) not null unique,
    activo boolean not null default true,
    creado_en date not null default current_date
    
);


-- 2. roles
create table rol (
    rol_id SERIAL primary key,
    nombre varchar(50) not null unique,
    descripcion varchar(255)
);


-- 3. roles asignados a los usuarios
create table usuario_rol (
    usuario_id int not null,
    rol_id int not null,
    asignado_por int,
    asignado_en timestamp not null default current_timestamp,

    primary key (usuario_id, rol_id),

    foreign key (usuario_id)
        references usuario(usuario_id)
        on delete cascade,

    foreign key (rol_id)
        references rol(rol_id)
        on delete restrict,

    foreign key (asignado_por)
        references usuario(usuario_id)
        on delete set null
);


-- 4. sesiones de los usuarios
create table sesion_usuario (
    sesion_id serial primary key,
    usuario_id int not null,
    refresh_token_hash varchar(255) not null unique,
    direccion_ip varchar(45),
    dispositivo text,
    creado_en timestamp not null default current_timestamp,
    expira_en timestamp not null,
    revocada_en timestamp,

    foreign key (usuario_id)
        references usuario(usuario_id)
        on delete cascade,

    check (expira_en > creado_en),

    check (
        revocada_en is null
        or revocada_en >= creado_en
    )
);

-- 5. configuración de seguridad

create table configuracion_seguridad (
    configuracion_id serial primary key,
    usuario_id int not null unique,
    verificacion_dos_pasos boolean not null default false,
    recibir_alertas_acceso boolean not null default true,
    actualizado_en timestamp not null default current_timestamp,

    foreign key (usuario_id)
        references usuario(usuario_id)
        on delete cascade
);

-- =====================================================
-- tablas geográficas - ciclistapp
-- =====================================================


-- 6. municipios
create table municipio(
    municipio_id serial primary key,
    nombre varchar(100) not null unique,
    clave_inegi varchar(10) not null unique
);


-- 7. colonias
create table colonia (
    colonia_id serial primary key,
    municipio_id int not null,
    nombre varchar(120) not null,
    codigo_postal varchar(10),

    unique (municipio_id, nombre),

    foreign key (municipio_id)
        references municipio(municipio_id)
        on delete restrict
);


-- 8. ciclovías
create table ciclovia (
    ciclovia_id serial primary key,
    nombre varchar(150) not null,
    descripcion text,
    fecha_alta date not null default current_date,
    activa boolean not null default true
);


-- 9. tramos de las ciclovías
create table tramo_ciclovia (
    tramo_id serial primary key,
    ciclovia_id int not null,
    nombre varchar(150) not null,

    latitud_inicio decimal(9,6) not null,
    longitud_inicio decimal(9,6) not null,
    latitud_fin decimal(9,6) not null,
    longitud_fin decimal(9,6) not null,

    longitud_m decimal(10,2) not null,
    sentido varchar(20),
    activo boolean not null default true,

    foreign key (ciclovia_id)
        references ciclovia(ciclovia_id)
        on delete cascade,

    check (latitud_inicio between -90 and 90),
    check (latitud_fin between -90 and 90),

    check (longitud_inicio between -180 and 180),
    check (longitud_fin between -180 and 180),

    check (longitud_m > 0)
);


-- 10. relación entre tramos y colonias
create table tramo_colonia (
    tramo_id int not null,
    colonia_id int not null,
    es_principal boolean not null default false,

    primary key (tramo_id, colonia_id),

    foreign key (tramo_id)
        references tramo_ciclovia(tramo_id)
        on delete cascade,

    foreign key (colonia_id)
        references colonia(colonia_id)
        on delete cascade
);

-- =====================================================
-- tablas administrativas - ciclistapp
-- =====================================================
-- los usuarios de estas tablas deben tener un rol administrativo
-- asignado mediante la tabla usuario_rol

-- 11. acciones del administrador 
create table acciones_administrador(
    accion_id serial primary key,
    realizado_por int not null,
    entidad_afectada varchar(100), -- ej: usuario, ciclovia, tramo
    entidad_id int,
    realizado_en timestamp default current_timestamp, 

    foreign key (realizado_por)
        references usuario(usuario_id)
        on delete restrict
);
-- 12. configuracion de sistema
create table configuracion_sistema(
    config_id serial primary key,
    clave varchar(100) not null unique,
    valor text not null,
    actualizado_por int,
    actualizado_en timestamp default current_timestamp,

        foreign key (actualizado_por)
            references usuario(usuario_id)
            on delete set null
);
-- 13. reportes del administrador 
create table reportes_admin(
    reporte_id  serial primary key,
    creado_por int not null,
    titulo varchar(150) not null,
    contenido text,
    creado_en timestamp default current_timestamp,

        foreign key (creado_por)
            references usuario(usuario_id)
            on delete restrict
);
-- ============================================================
-- 14. PLANES DE SUSCRIPCIÓN
-- ============================================================

CREATE TABLE plan_suscripcion (
    plan_id SERIAL NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion TEXT,
    precio_mensual DECIMAL(10,2) NOT NULL,
    duracion_dias INT NOT NULL DEFAULT 30,
    rutas_personalizadas BOOLEAN NOT NULL DEFAULT FALSE,
    historial_avanzado BOOLEAN NOT NULL DEFAULT FALSE,
    soporte_prioritario BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_plan_suscripcion
        PRIMARY KEY (plan_id),

    CONSTRAINT uq_plan_suscripcion_nombre
        UNIQUE (nombre),

    CONSTRAINT chk_plan_precio
        CHECK (precio_mensual >= 0),

    CONSTRAINT chk_plan_duracion
        CHECK (duracion_dias > 0)
);


-- ============================================================
-- 15. SUSCRIPCIONES DE USUARIOS
-- ============================================================

CREATE TABLE suscripcion (
    suscripcion_id SERIAL NOT NULL,
    usuario_id INT NOT NULL,
    plan_id INT NOT NULL,

    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE NOT NULL,

    estado VARCHAR(20) NOT NULL DEFAULT 'activa',
    renovacion_automatica BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_suscripcion
        PRIMARY KEY (suscripcion_id),

    CONSTRAINT fk_suscripcion_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_suscripcion_plan
        FOREIGN KEY (plan_id)
        REFERENCES plan_suscripcion(plan_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_suscripcion_estado
        CHECK (
            estado IN (
                'activa',
                'cancelada',
                'vencida',
                'pendiente'
            )
        ),

    CONSTRAINT chk_suscripcion_fechas
        CHECK (fecha_fin >= fecha_inicio)
);


-- ============================================================
-- 16. MÉTODOS DE PAGO
-- ============================================================

CREATE TABLE metodo_pago (
    metodo_pago_id SERIAL NOT NULL,
    usuario_id INT NOT NULL,

    tipo VARCHAR(30) NOT NULL,
    proveedor VARCHAR(50),

    ultimos_cuatro VARCHAR(4),
    token_pago VARCHAR(255),

    predeterminado BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_metodo_pago
        PRIMARY KEY (metodo_pago_id),

    CONSTRAINT fk_metodo_pago_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT uq_metodo_pago_token
        UNIQUE (token_pago),

    CONSTRAINT chk_metodo_pago_tipo
        CHECK (
            tipo IN (
                'tarjeta',
                'paypal',
                'mercado_pago',
                'transferencia'
            )
        ),

    CONSTRAINT chk_metodo_pago_ultimos_cuatro
        CHECK (
            ultimos_cuatro IS NULL
            OR ultimos_cuatro ~ '^[0-9]{4}$'
        )
);


-- ============================================================
-- 17. PAGOS
-- ============================================================

CREATE TABLE pago (
    pago_id SERIAL NOT NULL,

    suscripcion_id INT NOT NULL,
    metodo_pago_id INT,

    monto DECIMAL(10,2) NOT NULL,
    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    referencia VARCHAR(120),

    CONSTRAINT pk_pago
        PRIMARY KEY (pago_id),

    CONSTRAINT uq_pago_referencia
        UNIQUE (referencia),

    CONSTRAINT fk_pago_suscripcion
        FOREIGN KEY (suscripcion_id)
        REFERENCES suscripcion(suscripcion_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_pago_metodo
        FOREIGN KEY (metodo_pago_id)
        REFERENCES metodo_pago(metodo_pago_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_pago_monto
        CHECK (monto >= 0),

    CONSTRAINT chk_pago_estado
        CHECK (
            estado IN (
                'pendiente',
                'pagado',
                'rechazado',
                'reembolsado'
            )
        )
);


-- ============================================================
-- 18. BICICLETAS DE USUARIOS
-- ============================================================

CREATE TABLE bicicleta (
    bicicleta_id SERIAL NOT NULL,
    usuario_id INT NOT NULL,

    nombre VARCHAR(100),
    tipo VARCHAR(40) NOT NULL,
    marca VARCHAR(80),
    modelo VARCHAR(80),
    rodada VARCHAR(20),

    activa BOOLEAN NOT NULL DEFAULT TRUE,
    creada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_bicicleta
        PRIMARY KEY (bicicleta_id),

    CONSTRAINT fk_bicicleta_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT chk_bicicleta_tipo
        CHECK (
            tipo IN (
                'urbana',
                'montaña',
                'ruta',
                'electrica',
                'plegable',
                'hibrida',
                'otra'
            )
        )
);


-- ============================================================
-- 19. RUTAS
-- ============================================================

CREATE TABLE ruta (
    ruta_id SERIAL NOT NULL,

    creada_por INT,

    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,

    latitud_inicio DECIMAL(9,6) NOT NULL,
    longitud_inicio DECIMAL(9,6) NOT NULL,

    latitud_fin DECIMAL(9,6) NOT NULL,
    longitud_fin DECIMAL(9,6) NOT NULL,

    distancia_m DECIMAL(10,2) NOT NULL,
    duracion_estimada_min INT,

    dificultad VARCHAR(20) NOT NULL DEFAULT 'media',

    publica BOOLEAN NOT NULL DEFAULT TRUE,
    activa BOOLEAN NOT NULL DEFAULT TRUE,

    creada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ruta
        PRIMARY KEY (ruta_id),

    CONSTRAINT fk_ruta_usuario
        FOREIGN KEY (creada_por)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_ruta_latitud_inicio
        CHECK (latitud_inicio BETWEEN -90 AND 90),

    CONSTRAINT chk_ruta_latitud_fin
        CHECK (latitud_fin BETWEEN -90 AND 90),

    CONSTRAINT chk_ruta_longitud_inicio
        CHECK (longitud_inicio BETWEEN -180 AND 180),

    CONSTRAINT chk_ruta_longitud_fin
        CHECK (longitud_fin BETWEEN -180 AND 180),

    CONSTRAINT chk_ruta_distancia
        CHECK (distancia_m > 0),

    CONSTRAINT chk_ruta_duracion
        CHECK (
            duracion_estimada_min IS NULL
            OR duracion_estimada_min > 0
        ),

    CONSTRAINT chk_ruta_dificultad
        CHECK (
            dificultad IN (
                'facil',
                'media',
                'dificil'
            )
        )
);


-- ============================================================
-- 20. RELACIÓN ENTRE RUTAS Y TRAMOS DE CICLOVÍA
-- ============================================================

CREATE TABLE ruta_tramo (
    ruta_id INT NOT NULL,
    tramo_id INT NOT NULL,

    orden INT NOT NULL,

    CONSTRAINT pk_ruta_tramo
        PRIMARY KEY (ruta_id, tramo_id),

    CONSTRAINT fk_ruta_tramo_ruta
        FOREIGN KEY (ruta_id)
        REFERENCES ruta(ruta_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_ruta_tramo_tramo
        FOREIGN KEY (tramo_id)
        REFERENCES tramo_ciclovia(tramo_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT uq_ruta_tramo_orden
        UNIQUE (ruta_id, orden),

    CONSTRAINT chk_ruta_tramo_orden
        CHECK (orden > 0)
);


-- ============================================================
-- 21. RUTAS FAVORITAS
-- ============================================================

CREATE TABLE ruta_favorita (
    usuario_id INT NOT NULL,
    ruta_id INT NOT NULL,

    guardada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ruta_favorita
        PRIMARY KEY (usuario_id, ruta_id),

    CONSTRAINT fk_ruta_favorita_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_ruta_favorita_ruta
        FOREIGN KEY (ruta_id)
        REFERENCES ruta(ruta_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


-- ============================================================
-- 22. RECORRIDOS REALIZADOS
-- ============================================================

CREATE TABLE recorrido (
    recorrido_id SERIAL NOT NULL,

    usuario_id INT NOT NULL,
    bicicleta_id INT,
    ruta_id INT,

    inicio TIMESTAMP NOT NULL,
    fin TIMESTAMP,

    distancia_m DECIMAL(10,2),
    duracion_segundos INT,

    velocidad_promedio_kmh DECIMAL(6,2),
    velocidad_maxima_kmh DECIMAL(6,2),

    estado VARCHAR(20) NOT NULL DEFAULT 'en_progreso',

    CONSTRAINT pk_recorrido
        PRIMARY KEY (recorrido_id),

    CONSTRAINT fk_recorrido_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_recorrido_bicicleta
        FOREIGN KEY (bicicleta_id)
        REFERENCES bicicleta(bicicleta_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_recorrido_ruta
        FOREIGN KEY (ruta_id)
        REFERENCES ruta(ruta_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_recorrido_fechas
        CHECK (
            fin IS NULL
            OR fin >= inicio
        ),

    CONSTRAINT chk_recorrido_distancia
        CHECK (
            distancia_m IS NULL
            OR distancia_m >= 0
        ),

    CONSTRAINT chk_recorrido_duracion
        CHECK (
            duracion_segundos IS NULL
            OR duracion_segundos >= 0
        ),

    CONSTRAINT chk_recorrido_velocidad_promedio
        CHECK (
            velocidad_promedio_kmh IS NULL
            OR velocidad_promedio_kmh >= 0
        ),

    CONSTRAINT chk_recorrido_velocidad_maxima
        CHECK (
            velocidad_maxima_kmh IS NULL
            OR velocidad_maxima_kmh >= 0
        ),

    CONSTRAINT chk_recorrido_estado
        CHECK (
            estado IN (
                'en_progreso',
                'completado',
                'cancelado'
            )
        )
);


-- ============================================================
-- 23. PUNTOS GPS DE LOS RECORRIDOS
-- ============================================================

CREATE TABLE recorrido_punto (
    punto_id BIGSERIAL NOT NULL,

    recorrido_id INT NOT NULL,

    latitud DECIMAL(9,6) NOT NULL,
    longitud DECIMAL(9,6) NOT NULL,

    altitud_m DECIMAL(8,2),
    velocidad_kmh DECIMAL(6,2),

    registrado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_recorrido_punto
        PRIMARY KEY (punto_id),

    CONSTRAINT fk_recorrido_punto_recorrido
        FOREIGN KEY (recorrido_id)
        REFERENCES recorrido(recorrido_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT chk_recorrido_punto_latitud
        CHECK (latitud BETWEEN -90 AND 90),

    CONSTRAINT chk_recorrido_punto_longitud
        CHECK (longitud BETWEEN -180 AND 180),

    CONSTRAINT chk_recorrido_punto_velocidad
        CHECK (
            velocidad_kmh IS NULL
            OR velocidad_kmh >= 0
        )
);


-- ============================================================
-- 24. INCIDENCIAS
-- ============================================================

CREATE TABLE incidencia (
    incidencia_id SERIAL NOT NULL,

    usuario_id INT NOT NULL,
    tramo_id INT,

    tipo VARCHAR(40) NOT NULL,
    descripcion TEXT NOT NULL,

    latitud DECIMAL(9,6),
    longitud DECIMAL(9,6),

    nivel VARCHAR(20) NOT NULL DEFAULT 'media',
    estado VARCHAR(20) NOT NULL DEFAULT 'reportada',

    reportada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resuelta_en TIMESTAMP,

    CONSTRAINT pk_incidencia
        PRIMARY KEY (incidencia_id),

    CONSTRAINT fk_incidencia_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_incidencia_tramo
        FOREIGN KEY (tramo_id)
        REFERENCES tramo_ciclovia(tramo_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_incidencia_tipo
        CHECK (
            tipo IN (
                'bache',
                'accidente',
                'obra',
                'bloqueo',
                'inseguridad',
                'inundacion',
                'semaforo',
                'otro'
            )
        ),

    CONSTRAINT chk_incidencia_nivel
        CHECK (
            nivel IN (
                'baja',
                'media',
                'alta',
                'critica'
            )
        ),

    CONSTRAINT chk_incidencia_estado
        CHECK (
            estado IN (
                'reportada',
                'en_revision',
                'resuelta',
                'descartada'
            )
        ),

    CONSTRAINT chk_incidencia_latitud
        CHECK (
            latitud IS NULL
            OR latitud BETWEEN -90 AND 90
        ),

    CONSTRAINT chk_incidencia_longitud
        CHECK (
            longitud IS NULL
            OR longitud BETWEEN -180 AND 180
        ),

    CONSTRAINT chk_incidencia_fecha_resuelta
        CHECK (
            resuelta_en IS NULL
            OR resuelta_en >= reportada_en
        )
);


-- ============================================================
-- 25. CALIFICACIONES DE RUTAS
-- ============================================================

CREATE TABLE calificacion_ruta (
    calificacion_id SERIAL NOT NULL,

    usuario_id INT NOT NULL,
    ruta_id INT NOT NULL,

    puntuacion INT NOT NULL,
    comentario TEXT,

    creada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_calificacion_ruta
        PRIMARY KEY (calificacion_id),

    CONSTRAINT fk_calificacion_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuario(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_calificacion_ruta
        FOREIGN KEY (ruta_id)
        REFERENCES ruta(ruta_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT uq_calificacion_usuario_ruta
        UNIQUE (usuario_id, ruta_id),

    CONSTRAINT chk_calificacion_puntuacion
        CHECK (puntuacion BETWEEN 1 AND 5)
);


-- ============================================================
-- 26. PUNTOS DE INTERÉS
-- ============================================================

CREATE TABLE punto_interes (
    punto_interes_id SERIAL NOT NULL,

    nombre VARCHAR(150) NOT NULL,
    tipo VARCHAR(40) NOT NULL,

    descripcion TEXT,

    latitud DECIMAL(9,6) NOT NULL,
    longitud DECIMAL(9,6) NOT NULL,

    direccion VARCHAR(255),

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_punto_interes
        PRIMARY KEY (punto_interes_id),

    CONSTRAINT chk_punto_interes_latitud
        CHECK (latitud BETWEEN -90 AND 90),

    CONSTRAINT chk_punto_interes_longitud
        CHECK (longitud BETWEEN -180 AND 180),

    CONSTRAINT chk_punto_interes_tipo
        CHECK (
            tipo IN (
                'taller',
                'estacion_bicicletas',
                'estacionamiento',
                'tienda',
                'agua',
                'hospital',
                'parque',
                'otro'
            )
        )
);


-- ============================================================
-- 27. RELACIÓN RUTA - PUNTO DE INTERÉS
-- ============================================================

CREATE TABLE ruta_punto_interes (
    ruta_id INT NOT NULL,
    punto_interes_id INT NOT NULL,

    orden INT,

    CONSTRAINT pk_ruta_punto_interes
        PRIMARY KEY (ruta_id, punto_interes_id),

    CONSTRAINT fk_ruta_punto_interes_ruta
        FOREIGN KEY (ruta_id)
        REFERENCES ruta(ruta_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_ruta_punto_interes_punto
        FOREIGN KEY (punto_interes_id)
        REFERENCES punto_interes(punto_interes_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT chk_ruta_punto_interes_orden
        CHECK (
            orden IS NULL
            OR orden > 0
        )
);


-- ============================================================
-- 28. estaciones de bicicletas
-- ============================================================

create table estacion_bicicleta (
    estacion_id serial primary key,
    punto_interes_id int not null unique,

    capacidad int not null,
    bicicletas_disponibles int not null default 0,
    espacios_disponibles int not null default 0,

    horario_apertura time,
    horario_cierre time,

    estado varchar(20) not null default 'activa',
    actualizada_en timestamp not null default current_timestamp,

    foreign key (punto_interes_id)
        references punto_interes(punto_interes_id)
        on update cascade
        on delete cascade,

    check (capacidad > 0),

    check (
        bicicletas_disponibles >= 0
        and bicicletas_disponibles <= capacidad
    ),

    check (
        espacios_disponibles >= 0
        and espacios_disponibles <= capacidad
    ),

    check (
        bicicletas_disponibles + espacios_disponibles <= capacidad
    ),

    check (
        estado in (
            'activa',
            'inactiva',
            'mantenimiento'
        )
    )
);


-- ============================================================
-- 29. historial de estados de las incidencias
-- ============================================================

create table historial_estado_incidencia (
    historial_id serial primary key,
    incidencia_id int not null,
    cambiado_por int not null,

    estado_anterior varchar(20),
    estado_nuevo varchar(20) not null,
    comentario text,

    cambiado_en timestamp not null default current_timestamp,

    foreign key (incidencia_id)
        references incidencia(incidencia_id)
        on update cascade
        on delete cascade,

    foreign key (cambiado_por)
        references usuario(usuario_id)
        on update cascade
        on delete restrict,

    check (
        estado_anterior is null
        or estado_anterior in (
            'reportada',
            'en_revision',
            'resuelta',
            'descartada'
        )
    ),

    check (
        estado_nuevo in (
            'reportada',
            'en_revision',
            'resuelta',
            'descartada'
        )
    ),

    check (
        estado_anterior is null
        or estado_anterior <> estado_nuevo
    )
);


-- ============================================================
-- 30. notificaciones de los usuarios
-- ============================================================

create table notificacion (
    notificacion_id serial primary key,
    usuario_id int not null,

    incidencia_id int,
    ruta_id int,
    pago_id int,
    suscripcion_id int,

    tipo varchar(30) not null,
    titulo varchar(150) not null,
    mensaje text not null,

    leida boolean not null default false,
    creada_en timestamp not null default current_timestamp,
    leida_en timestamp,

    foreign key (usuario_id)
        references usuario(usuario_id)
        on update cascade
        on delete cascade,

    foreign key (incidencia_id)
        references incidencia(incidencia_id)
        on update cascade
        on delete set null,

    foreign key (ruta_id)
        references ruta(ruta_id)
        on update cascade
        on delete set null,

    foreign key (pago_id)
        references pago(pago_id)
        on update cascade
        on delete set null,

    foreign key (suscripcion_id)
        references suscripcion(suscripcion_id)
        on update cascade
        on delete set null,

    check (
        tipo in (
            'incidencia',
            'ruta',
            'pago',
            'suscripcion',
            'sistema'
        )
    ),

    check (
        leida_en is null
        or leida_en >= creada_en
    )
);