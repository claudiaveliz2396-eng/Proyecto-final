// =====================================================
// COLECCIÓN 1: usuarios
// Agrupa: usuario, rol, usuario_rol, sesion_usuario, configuracion_seguridad, 
// metodo_pago, bicicleta, ruta_favorita
// =====================================================
db.createCollection("usuarios", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["correo", "password_hash", "nombre", "alias"],
      properties: {
        correo: { bsonType: "string" },
        password_hash: { bsonType: "string" },
        nombre: { bsonType: "string" },
        alias: { bsonType: "string" },
        activo: { bsonType: "bool" },
        creado_en: { bsonType: "date" },
        roles: { 
          bsonType: "array", 
          items: { bsonType: "string" } // Ej: ["admin", "usuario_base"]
        },
        configuracion_seguridad: {
          bsonType: "object",
          properties: {
            verificacion_dos_pasos: { bsonType: "bool" },
            recibir_alertas_acceso: { bsonType: "bool" },
            actualizado_en: { bsonType: "date" }
          }
        },
        sesiones: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              refresh_token_hash: { bsonType: "string" },
              direccion_ip: { bsonType: "string" },
              dispositivo: { bsonType: "string" },
              creado_en: { bsonType: "date" },
              expira_en: { bsonType: "date" },
              revocada_en: { bsonType: ["date", "null"] }
            }
          }
        },
        metodos_pago: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              tipo: { enum: ["tarjeta", "paypal", "mercado_pago", "transferencia"] },
              proveedor: { bsonType: "string" },
              ultimos_cuatro: { bsonType: "string" },
              token_pago: { bsonType: "string" },
              predeterminado: { bsonType: "bool" },
              activo: { bsonType: "bool" }
            }
          }
        },
        bicicletas: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              bicicleta_id: { bsonType: "objectId" }, // Generado internamente si se requiere referencia
              nombre: { bsonType: "string" },
              tipo: { enum: ["urbana", "montaña", "ruta", "electrica", "plegable", "hibrida", "otra"] },
              marca: { bsonType: "string" },
              modelo: { bsonType: "string" },
              rodada: { bsonType: "string" },
              activa: { bsonType: "bool" }
            }
          }
        },
        rutas_favoritas: {
          bsonType: "array",
          items: { bsonType: "objectId" } // Referencias a la colección "rutas"
        }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 2: ciclovias
// Agrupa: ciclovia, tramo_ciclovia, tramo_colonia, colonia, municipio
// =====================================================
db.createCollection("ciclovias", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["nombre"],
      properties: {
        nombre: { bsonType: "string" },
        descripcion: { bsonType: "string" },
        fecha_alta: { bsonType: "date" },
        activa: { bsonType: "bool" },
        tramos: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              tramo_id: { bsonType: "objectId" },
              nombre: { bsonType: "string" },
              ubicacion_inicio: { // GeoJSON
                type: { enum: ["Point"] },
                coordinates: { bsonType: "array" } // [longitud, latitud]
              },
              ubicacion_fin: { type: { enum: ["Point"] }, coordinates: { bsonType: "array" } },
              longitud_m: { bsonType: "double" },
              sentido: { bsonType: "string" },
              activo: { bsonType: "bool" },
              colonias_asociadas: {
                bsonType: "array",
                items: {
                  bsonType: "object",
                  properties: {
                    nombre_colonia: { bsonType: "string" },
                    codigo_postal: { bsonType: "string" },
                    municipio: { bsonType: "string" },
                    clave_inegi: { bsonType: "string" },
                    es_principal: { bsonType: "bool" }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 3: rutas
// Agrupa: ruta, ruta_tramo, ruta_punto_interes, calificacion_ruta
// =====================================================
db.createCollection("rutas", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["nombre", "creada_por"],
      properties: {
        creada_por: { bsonType: "objectId" }, // Referencia a usuarios
        nombre: { bsonType: "string" },
        descripcion: { bsonType: "string" },
        ubicacion_inicio: { type: { enum: ["Point"] }, coordinates: { bsonType: "array" } },
        ubicacion_fin: { type: { enum: ["Point"] }, coordinates: { bsonType: "array" } },
        distancia_m: { bsonType: "double" },
        duracion_estimada_min: { bsonType: "int" },
        dificultad: { enum: ["facil", "media", "dificil"] },
        publica: { bsonType: "bool" },
        activa: { bsonType: "bool" },
        creada_en: { bsonType: "date" },
        tramos_secuencia: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              tramo_id: { bsonType: "objectId" }, // Referencia a subdocumento en ciclovias
              orden: { bsonType: "int" }
            }
          }
        },
        puntos_interes_secuencia: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              punto_interes_id: { bsonType: "objectId" }, // Referencia a puntos_interes
              orden: { bsonType: "int" }
            }
          }
        },
        calificaciones: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              usuario_id: { bsonType: "objectId" },
              puntuacion: { bsonType: "int", minimum: 1, maximum: 5 },
              comentario: { bsonType: "string" },
              creada_en: { bsonType: "date" }
            }
          }
        }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 4: recorridos
// Agrupa: recorrido, recorrido_punto
// =====================================================
db.createCollection("recorridos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["usuario_id", "inicio", "estado"],
      properties: {
        usuario_id: { bsonType: "objectId" },
        bicicleta_id: { bsonType: "objectId" }, // Referencia a subdocumento en usuarios
        ruta_id: { bsonType: "objectId" }, // Opcional
        inicio: { bsonType: "date" },
        fin: { bsonType: "date" },
        distancia_m: { bsonType: "double" },
        duracion_segundos: { bsonType: "int" },
        velocidad_promedio_kmh: { bsonType: "double" },
        velocidad_maxima_kmh: { bsonType: "double" },
        estado: { enum: ["en_progreso", "completado", "cancelado"] },
        // En MongoDB, si los puntos GPS (Time Series) son masivos (miles por viaje), 
        // es mejor crear una colección Time Series separada. Si son reducidos, se embeben:
        puntos_gps: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              coordenadas: { type: { enum: ["Point"] }, coordinates: { bsonType: "array" } },
              altitud_m: { bsonType: "double" },
              velocidad_kmh: { bsonType: "double" },
              registrado_en: { bsonType: "date" }
            }
          }
        }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 5: incidencias
// Agrupa: incidencia, historial_estado_incidencia
// =====================================================
db.createCollection("incidencias", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["usuario_id", "tipo", "descripcion"],
      properties: {
        usuario_id: { bsonType: "objectId" },
        tramo_id: { bsonType: "objectId" },
        tipo: { enum: ["bache", "accidente", "obra", "bloqueo", "inseguridad", "inundacion", "semaforo", "otro"] },
        descripcion: { bsonType: "string" },
        ubicacion: { type: { enum: ["Point"] }, coordinates: { bsonType: "array" } },
        nivel: { enum: ["baja", "media", "alta", "critica"] },
        estado: { enum: ["reportada", "en_revision", "resuelta", "descartada"] },
        reportada_en: { bsonType: "date" },
        resuelta_en: { bsonType: ["date", "null"] },
        historial_estados: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              cambiado_por: { bsonType: "objectId" }, // Usuario admin
              estado_anterior: { bsonType: "string" },
              estado_nuevo: { bsonType: "string" },
              comentario: { bsonType: "string" },
              cambiado_en: { bsonType: "date" }
            }
          }
        }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 6: suscripciones
// Agrupa: suscripcion, plan_suscripcion, pago
// =====================================================
db.createCollection("suscripciones", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["usuario_id", "estado"],
      properties: {
        usuario_id: { bsonType: "objectId" },
        plan: {
          bsonType: "object",
          properties: {
            plan_id: { bsonType: "objectId" }, // Referencia a colección maestra de planes o embebido
            nombre: { bsonType: "string" },
            precio_mensual: { bsonType: "double" },
            duracion_dias: { bsonType: "int" },
            rutas_personalizadas: { bsonType: "bool" },
            historial_avanzado: { bsonType: "bool" },
            soporte_prioritario: { bsonType: "bool" }
          }
        },
        fecha_inicio: { bsonType: "date" },
        fecha_fin: { bsonType: "date" },
        estado: { enum: ["activa", "cancelada", "vencida", "pendiente"] },
        renovacion_automatica: { bsonType: "bool" },
        historial_pagos: {
          bsonType: "array",
          items: {
            bsonType: "object",
            properties: {
              metodo_pago_token: { bsonType: "string" },
              monto: { bsonType: "double" },
              fecha_pago: { bsonType: "date" },
              estado: { enum: ["pendiente", "pagado", "rechazado", "reembolsado"] },
              referencia: { bsonType: "string" }
            }
          }
        }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 7: puntos_interes
// Agrupa: punto_interes, estacion_bicicleta
// =====================================================
db.createCollection("puntos_interes", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["nombre", "tipo"],
      properties: {
        nombre: { bsonType: "string" },
        tipo: { enum: ["taller", "estacion_bicicletas", "estacionamiento", "tienda", "agua", "hospital", "parque", "otro"] },
        descripcion: { bsonType: "string" },
        ubicacion: { type: { enum: ["Point"] }, coordinates: { bsonType: "array" } },
        direccion: { bsonType: "string" },
        activo: { bsonType: "bool" },
        // Embebido condicional si el tipo es 'estacion_bicicletas'
        detalles_estacion: {
          bsonType: "object",
          properties: {
            capacidad: { bsonType: "int" },
            bicicletas_disponibles: { bsonType: "int" },
            espacios_disponibles: { bsonType: "int" },
            horario_apertura: { bsonType: "string" },
            horario_cierre: { bsonType: "string" },
            estado: { enum: ["activa", "inactiva", "mantenimiento"] },
            actualizada_en: { bsonType: "date" }
          }
        }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 8: notificaciones
// Agrupa: notificacion
// =====================================================
db.createCollection("notificaciones", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["usuario_id", "tipo", "titulo", "mensaje"],
      properties: {
        usuario_id: { bsonType: "objectId" },
        referencia_origen_id: { bsonType: "objectId" }, // ID genérico para incidencia, ruta, etc.
        tipo: { enum: ["incidencia", "ruta", "pago", "suscripcion", "sistema"] },
        titulo: { bsonType: "string" },
        mensaje: { bsonType: "string" },
        leida: { bsonType: "bool" },
        creada_en: { bsonType: "date" },
        leida_en: { bsonType: ["date", "null"] }
      }
    }
  }
});

// =====================================================
// COLECCIÓN 9: administracion
// Agrupa: acciones_administrador, configuracion_sistema, reportes_admin
// =====================================================
db.createCollection("administracion", {
  // Aquí puedes almacenar configuraciones globales tipo Key-Value y reportes.
  // Ejemplo documento de configuración: { _id: "config_sistema", limites_velocidad: 50, ... }
  // Ejemplo documento de log de acciones: { tipo: "log_accion", realizado_por: ObjectId, entidad: "usuario", accion: "baneo", fecha: Date }
});
