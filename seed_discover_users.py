"""
seed_discover_users.py
======================
Genera usuarios ficticios de migrantes latinoamericanos en Firestore
para probar la funcionalidad de Nomad Connect (discover/citas).

Uso:
    1. Poné tu serviceAccountKey.json en la misma carpeta
    2. pip install firebase-admin
    3. python seed_discover_users.py
    4. python seed_discover_users.py --delete   ← borra los usuarios de prueba

Crea 20 usuarios ficticios con:
  - Datos de perfil realistas (nombre, bio, edad, país, ciudad)
  - Ruta migrante (ciudadesVividas)
  - Objetivos migratorios variados
  - discoverVisible: true
  - Fotos de avatar de UI Avatars (sin copyright)

Los documentos se crean en /users/{uid_ficticio}
El UID ficticio empieza con "seed_" para identificarlos fácilmente.
"""

import json
import uuid
import argparse
from pathlib import Path
from datetime import datetime, timezone

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("❌ Instalá firebase-admin: pip install firebase-admin")
    exit(1)

# ─────────────────────────────────────────────────────────────────────────────
# DATOS FICTICIOS
# ─────────────────────────────────────────────────────────────────────────────

USUARIOS = [
    {
        "nombre": "Valentina Rodríguez",
        "username": "vale_rodri",
        "bio": "Diseñadora UX. Me fui de Montevideo hace 2 años buscando nuevos proyectos. Madrid me sorprendió para bien 🌞",
        "edad": 28,
        "paisOrigen": "Uruguay",
        "countryFlag": "🇺🇾",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Trámites de residencia", "Buscar trabajo en tech"],
        "ciudadesVividas": [
            {"ciudad": "Montevideo", "pais": "Uruguay", "emoji": "🇺🇾", "años": "1995-2022"},
            {"ciudad": "Buenos Aires", "pais": "Argentina", "emoji": "🇦🇷", "años": "2022"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2022-hoy"},
        ],
    },
    {
        "nombre": "Matías Fernández",
        "username": "mati_fdz",
        "bio": "Cocinero. Vine a España con el sueño de aprender gastronomía europea. Ahora trabajo en un restaurante en Barcelona 🍳",
        "edad": 32,
        "paisOrigen": "Argentina",
        "countryFlag": "🇦🇷",
        "ciudadActual": "Barcelona",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Gastronomía", "Encontrar trabajo sin papeles europeos"],
        "ciudadesVividas": [
            {"ciudad": "Córdoba", "pais": "Argentina", "emoji": "🇦🇷", "años": "1992-2020"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2020-2022"},
            {"ciudad": "Barcelona", "pais": "España", "emoji": "🇪🇸", "años": "2022-hoy"},
        ],
    },
    {
        "nombre": "Camila Torres",
        "username": "cami_torres",
        "bio": "Estudiante de máster en Comunicación. Colombiana en Madrid, aprendiendo a navegar el sistema universitario español 📚",
        "edad": 25,
        "paisOrigen": "Colombia",
        "countryFlag": "🇨🇴",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "estudiar",
        "areasAyuda": ["Sistema universitario español", "Becas para extranjeros"],
        "ciudadesVividas": [
            {"ciudad": "Bogotá", "pais": "Colombia", "emoji": "🇨🇴", "años": "2000-2023"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2023-hoy"},
        ],
    },
    {
        "nombre": "Diego Herrera",
        "username": "diegoherrera_uy",
        "bio": "Desarrollador backend. Uruguayo en Barcelona, trabajo remoto para empresa en EEUU. Nómada digital de corazón 💻",
        "edad": 30,
        "paisOrigen": "Uruguay",
        "countryFlag": "🇺🇾",
        "ciudadActual": "Barcelona",
        "migracionObjetivo": "nomada",
        "areasAyuda": ["Trabajo remoto legal", "Visa nómada digital"],
        "ciudadesVividas": [
            {"ciudad": "Montevideo", "pais": "Uruguay", "emoji": "🇺🇾", "años": "1994-2021"},
            {"ciudad": "Lisboa", "pais": "Portugal", "emoji": "🇵🇹", "años": "2021-2023"},
            {"ciudad": "Barcelona", "pais": "España", "emoji": "🇪🇸", "años": "2023-hoy"},
        ],
    },
    {
        "nombre": "Sofía Martínez",
        "username": "sofi_mtz",
        "bio": "Médica venezolana. Revalidando mi título en España. El proceso es largo pero vale la pena 🏥",
        "edad": 35,
        "paisOrigen": "Venezuela",
        "countryFlag": "🇻🇪",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Revalidación de títulos", "Sistema de salud español"],
        "ciudadesVividas": [
            {"ciudad": "Caracas", "pais": "Venezuela", "emoji": "🇻🇪", "años": "1989-2019"},
            {"ciudad": "Bogotá", "pais": "Colombia", "emoji": "🇨🇴", "años": "2019-2021"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2021-hoy"},
        ],
    },
    {
        "nombre": "Lucas Pérez",
        "username": "lucasperez_ar",
        "bio": "Emprendedor. Monté una startup en Lisboa con otros dos argentinos. El ecosistema tech europeo está buenísimo 🚀",
        "edad": 33,
        "paisOrigen": "Argentina",
        "countryFlag": "🇦🇷",
        "ciudadActual": "Lisboa",
        "migracionObjetivo": "emprender",
        "areasAyuda": ["Visa de emprendedor Portugal", "Inversores en Europa"],
        "ciudadesVividas": [
            {"ciudad": "Buenos Aires", "pais": "Argentina", "emoji": "🇦🇷", "años": "1991-2020"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2020-2022"},
            {"ciudad": "Lisboa", "pais": "Portugal", "emoji": "🇵🇹", "años": "2022-hoy"},
        ],
    },
    {
        "nombre": "Isabela Gomes",
        "username": "isa_gomes",
        "bio": "Profesora de portugués e inglés. Brasileira viviendo en Madrid, dando clases particulares y disfrutando la vida europea 🌍",
        "edad": 27,
        "paisOrigen": "Brasil",
        "countryFlag": "🇧🇷",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Clases de idiomas", "Trámites para brasileños en España"],
        "ciudadesVividas": [
            {"ciudad": "São Paulo", "pais": "Brasil", "emoji": "🇧🇷", "años": "1997-2022"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2022-hoy"},
        ],
    },
    {
        "nombre": "Andrés Molina",
        "username": "andres_molina_co",
        "bio": "Abogado colombiano reconvirtiendo mi carrera en España. Estudiando para la reválida. Si pasaste por esto, ¡hablemos! ⚖️",
        "edad": 38,
        "paisOrigen": "Colombia",
        "countryFlag": "🇨🇴",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Reválida de títulos jurídicos", "Arraigo laboral"],
        "ciudadesVividas": [
            {"ciudad": "Medellín", "pais": "Colombia", "emoji": "🇨🇴", "años": "1986-2022"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2022-hoy"},
        ],
    },
    {
        "nombre": "María José Sánchez",
        "username": "mariajo_uy",
        "bio": "Contadora pública. Vine a reunirme con mi marido que estaba acá desde antes. Ahora los dos construyendo nuestra vida en Europa 💛",
        "edad": 31,
        "paisOrigen": "Uruguay",
        "countryFlag": "🇺🇾",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "familia",
        "areasAyuda": ["Reagrupación familiar", "Convalidación de títulos contables"],
        "ciudadesVividas": [
            {"ciudad": "Salto", "pais": "Uruguay", "emoji": "🇺🇾", "años": "1993-2023"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2023-hoy"},
        ],
    },
    {
        "nombre": "Felipe Vargas",
        "username": "pipe_vargas",
        "bio": "Músico chileno tocando en bares de Barcelona. La vida del inmigrante artista es dura pero hermosa 🎸",
        "edad": 29,
        "paisOrigen": "Chile",
        "countryFlag": "🇨🇱",
        "ciudadActual": "Barcelona",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Visa de artista", "Trabajo en la industria musical europea"],
        "ciudadesVividas": [
            {"ciudad": "Santiago", "pais": "Chile", "emoji": "🇨🇱", "años": "1995-2021"},
            {"ciudad": "Buenos Aires", "pais": "Argentina", "emoji": "🇦🇷", "años": "2021-2022"},
            {"ciudad": "Barcelona", "pais": "España", "emoji": "🇪🇸", "años": "2022-hoy"},
        ],
    },
    {
        "nombre": "Carolina Ramírez",
        "username": "caro_ramirez_ve",
        "bio": "Ingeniera de sistemas. Venezolana en Madrid hace 4 años. Ya tengo la residencia y trabajo en una consultora tech 🖥️",
        "edad": 34,
        "paisOrigen": "Venezuela",
        "countryFlag": "🇻🇪",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "residir",
        "areasAyuda": ["Residencia permanente", "Trabajo en IT sin experiencia europea"],
        "ciudadesVividas": [
            {"ciudad": "Maracaibo", "pais": "Venezuela", "emoji": "🇻🇪", "años": "1990-2020"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2020-hoy"},
        ],
    },
    {
        "nombre": "Tomás Delgado",
        "username": "tomas_delgado_uy",
        "bio": "Arquitecto. Recién llegado a Madrid, buscando trabajo y adaptándome. El mate me ayuda a no extrañar tanto 🧉",
        "edad": 26,
        "paisOrigen": "Uruguay",
        "countryFlag": "🇺🇾",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Buscar trabajo en arquitectura", "Primeros pasos en España"],
        "ciudadesVividas": [
            {"ciudad": "Montevideo", "pais": "Uruguay", "emoji": "🇺🇾", "años": "1998-2024"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2024-hoy"},
        ],
    },
    {
        "nombre": "Natalia Quispe",
        "username": "nati_quispe",
        "bio": "Enfermera peruana. Trabajo en el Hospital La Paz. Llegué sola y construí mi red desde cero. Feliz de ayudar a quien empiece 🏥",
        "edad": 36,
        "paisOrigen": "Perú",
        "countryFlag": "🇵🇪",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Enfermería en España", "Proceso de homologación sanitaria"],
        "ciudadesVividas": [
            {"ciudad": "Lima", "pais": "Perú", "emoji": "🇵🇪", "años": "1988-2016"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2016-hoy"},
        ],
    },
    {
        "nombre": "Rodrigo Castillo",
        "username": "rodri_castillo_ar",
        "bio": "Periodista freelance. Escribo sobre la experiencia migrante latinoamericana en Europa. Nómada entre Madrid y Lisboa ✍️",
        "edad": 31,
        "paisOrigen": "Argentina",
        "countryFlag": "🇦🇷",
        "ciudadActual": "Lisboa",
        "migracionObjetivo": "nomada",
        "areasAyuda": ["Trabajo freelance en Europa", "Visa nómada Portugal"],
        "ciudadesVividas": [
            {"ciudad": "Rosario", "pais": "Argentina", "emoji": "🇦🇷", "años": "1993-2019"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2019-2023"},
            {"ciudad": "Lisboa", "pais": "Portugal", "emoji": "🇵🇹", "años": "2023-hoy"},
        ],
    },
    {
        "nombre": "Paula Moreno",
        "username": "pau_moreno_co",
        "bio": "Psicóloga. Haciendo el doctorado en la Autónoma de Madrid. La investigación académica me permite crecer y viajar 🧠",
        "edad": 29,
        "paisOrigen": "Colombia",
        "countryFlag": "🇨🇴",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "estudiar",
        "areasAyuda": ["Doctorado en España", "Becas para latinoamericanos"],
        "ciudadesVividas": [
            {"ciudad": "Cali", "pais": "Colombia", "emoji": "🇨🇴", "años": "1995-2022"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2022-hoy"},
        ],
    },
    {
        "nombre": "Javier Núñez",
        "username": "javi_nunez_mx",
        "bio": "Chef mexicano montando mi propio restaurante en Barcelona. Los tacos auténticos son mi aporte cultural a Europa 🌮",
        "edad": 40,
        "paisOrigen": "México",
        "countryFlag": "🇲🇽",
        "ciudadActual": "Barcelona",
        "migracionObjetivo": "emprender",
        "areasAyuda": ["Abrir negocio en España", "Visa de emprendedor"],
        "ciudadesVividas": [
            {"ciudad": "Ciudad de México", "pais": "México", "emoji": "🇲🇽", "años": "1984-2018"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2018-2021"},
            {"ciudad": "Barcelona", "pais": "España", "emoji": "🇪🇸", "años": "2021-hoy"},
        ],
    },
    {
        "nombre": "Luciana Vega",
        "username": "luci_vega_uy",
        "bio": "Trabajadora social. Llegué hace 3 años a Madrid para estar con mi pareja. Ahora trabajo en una ONG con migrantes 💙",
        "edad": 33,
        "paisOrigen": "Uruguay",
        "countryFlag": "🇺🇾",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "familia",
        "areasAyuda": ["Reagrupación familiar", "ONG y apoyo a migrantes"],
        "ciudadesVividas": [
            {"ciudad": "Paysandú", "pais": "Uruguay", "emoji": "🇺🇾", "años": "1991-2021"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2021-hoy"},
        ],
    },
    {
        "nombre": "Emilio Castro",
        "username": "emi_castro_ve",
        "bio": "Economista venezolano. Analista en banco español. El camino fue largo pero el esfuerzo valió la pena 📊",
        "edad": 37,
        "paisOrigen": "Venezuela",
        "countryFlag": "🇻🇪",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "trabajar",
        "areasAyuda": ["Sector financiero en España", "Arraigo social"],
        "ciudadesVividas": [
            {"ciudad": "Valencia", "pais": "Venezuela", "emoji": "🇻🇪", "años": "1987-2018"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2018-hoy"},
        ],
    },
    {
        "nombre": "Ana García",
        "username": "ana_garcia_cl",
        "bio": "Bióloga marina chilena haciendo investigación en el CSIC. Apasionada del mar y de aprender cosas nuevas 🐠🔬",
        "edad": 27,
        "paisOrigen": "Chile",
        "countryFlag": "🇨🇱",
        "ciudadActual": "Madrid",
        "migracionObjetivo": "estudiar",
        "areasAyuda": ["Investigación científica en España", "Becas CSIC"],
        "ciudadesVividas": [
            {"ciudad": "Valparaíso", "pais": "Chile", "emoji": "🇨🇱", "años": "1997-2023"},
            {"ciudad": "Madrid", "pais": "España", "emoji": "🇪🇸", "años": "2023-hoy"},
        ],
    },
    {
        "nombre": "Sebastián Rojas",
        "username": "sebas_rojas_ar",
        "bio": "Fotógrafo y videógrafo. Documentando la vida de los migrantes latinoamericanos en Europa. La cámara es mi pasaporte 📷",
        "edad": 28,
        "paisOrigen": "Argentina",
        "countryFlag": "🇦🇷",
        "ciudadActual": "Barcelona",
        "migracionObjetivo": "nomada",
        "areasAyuda": ["Trabajo creativo freelance", "Visa para artistas"],
        "ciudadesVividas": [
            {"ciudad": "Mendoza", "pais": "Argentina", "emoji": "🇦🇷", "años": "1996-2022"},
            {"ciudad": "Barcelona", "pais": "España", "emoji": "🇪🇸", "años": "2022-hoy"},
        ],
    },
]

# Fotos de avatar usando UI Avatars (sin copyright, sin auth requerida)
def avatar_url(nombre: str) -> str:
    inicial = nombre.replace(" ", "+")
    return f"https://ui-avatars.com/api/?name={inicial}&size=400&background=CCF7F1&color=0D9488&bold=true&font-size=0.4"

# ─────────────────────────────────────────────────────────────────────────────
# FIRESTORE
# ─────────────────────────────────────────────────────────────────────────────

CRED_PATH = "serviceAccountKey.json"
SEED_PREFIX = "seed_"

def init_firebase():
    if not Path(CRED_PATH).exists():
        print(f"❌ No se encontró {CRED_PATH}")
        print("   Descargalo desde Firebase Console → Configuración → Cuentas de servicio")
        exit(1)
    if not firebase_admin._apps:
        cred = credentials.Certificate(CRED_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def seed(db):
    print(f"\n🌱 Creando {len(USUARIOS)} usuarios ficticios...\n")
    batch = db.batch()
    count = 0

    for u in USUARIOS:
        uid  = f"{SEED_PREFIX}{u['username']}"
        ref  = db.collection("users").document(uid)
        nombre = u["nombre"]

        doc = {
            # Identidad
            "uid":           uid,
            "displayName":   nombre,
            "username":      u["username"],
            "bio":           u["bio"],
            "photoURL":      avatar_url(nombre),
            "coverURL":      None,
            # Perfil migrante
            "edad":          u["edad"],
            "paisOrigen":    u["paisOrigen"],
            "countryFlag":   u["countryFlag"],
            "ciudadActual":  u["ciudadActual"],
            "migracionObjetivo": u["migracionObjetivo"],
            "ciudadesVividas":   u["ciudadesVividas"],
            "areasAyuda":    u["areasAyuda"],
            # Discover
            "discoverVisible": True,
            "discoverFilters": {
                "paisOrigen": None,
                "ciudad":     None,
                "objetivo":   None,
                "edadMin":    18,
                "edadMax":    60,
            },
            # Meta
            "role":          "user",
            "isSeedUser":    True,   # ← marcador para borrarlo fácil
            "createdAt":     firestore.SERVER_TIMESTAMP,
        }

        batch.set(ref, doc, merge=True)
        count += 1
        print(f"  ✅ {nombre} (@{u['username']}) — {u['paisOrigen']} en {u['ciudadActual']}")

        # Firestore permite máximo 500 ops por batch
        if count % 499 == 0:
            batch.commit()
            batch = db.batch()

    batch.commit()
    print(f"\n✨ {count} usuarios creados en /users/seed_*")
    print("   Abrí el Discover en la app — deberían aparecer estos perfiles.")
    print("   Para borrarlos: python seed_discover_users.py --delete\n")

def delete_seeds(db):
    print("\n🗑️  Borrando usuarios de prueba (isSeedUser == true)...\n")
    snap  = db.collection("users").where("isSeedUser", "==", True).get()
    batch = db.batch()
    count = 0
    for doc in snap:
        batch.delete(doc.reference)
        count += 1
        print(f"  🗑  {doc.id}")
        if count % 499 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"\n✅ {count} usuarios de prueba eliminados.\n")

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Seed de usuarios ficticios para Nomad Connect"
    )
    parser.add_argument(
        "--delete",
        action="store_true",
        help="Borra todos los usuarios de prueba (isSeedUser == true)",
    )
    args = parser.parse_args()

    db = init_firebase()

    if args.delete:
        delete_seeds(db)
    else:
        seed(db)