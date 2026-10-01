-- =====================================================
-- tablas de usuarios - bykeride
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
-- tablas geográficas - bykeride
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