###########3faker para poblar MongoDB#############3
from pymongo import MongoClient
from faker import Faker

# Conexión a tu base de datos MongoDB
cliente = MongoClient("tu_cadena_de_conexion_mongo")
db = cliente["ciclistapp_db"]

faker = Faker('es_MX')

def generar_sesiones_falsas(cantidad):
    sesiones = []
    for _ in range(cantidad):
        sesion = {
            "usuario_id": faker.random_int(min=1, max=50), # Simula IDs de PostgreSQL
            "refresh_token_hash": faker.sha256(),
            "direccion_ip": faker.ipv4(),
            "dispositivo": faker.user_agent(),
            "creado_en": faker.date_time_this_year(),
            "expira_en": faker.future_datetime()
        }
        sesiones.append(sesion)
    
    db["sesion_usuario"].insert_many(sesiones)
    print(f"{cantidad} sesiones insertadas en MongoDB.")

if _name_ == "_main_":
    generar_sesiones_falsas(15) # Mínimo de 15 registros exigido
