-- =====================================================
-- tablas de usuarios - bykeride
-- postgresql
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