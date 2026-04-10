"""
enriquecer_titulos.py
=====================
Agrega el campo `subtitulo` a cada documento del JSON de migraciones,
derivándolo del slug de la URL cuando el scraper no pudo extraer
un tipo_autorizacion descriptivo.

También normaliza los títulos genéricos como "Residencia Legal"
para que la app pueda mostrar algo útil en la tarjeta.

Uso:
    python enriquecer_titulos.py                         # genera migraciones_v2_enriquecido.json
    python enriquecer_titulos.py --upload                # sube directo a Firestore
    python enriquecer_titulos.py --pais UY               # solo Uruguay
"""

import json
import re
import argparse
from pathlib import Path

INPUT_FILE  = "migraciones_v2.json"
OUTPUT_FILE = "migraciones_v2_enriquecido.json"
FIRESTORE_FILE = "firestore_migration_data_v2.json"

# ─────────────────────────────────────────────────────────────────────────────
# MAPA SLUG → SUBTÍTULO
# Cada entrada es: slug_del_tramite → subtítulo corto y claro para el usuario.
# Para agregar un país nuevo, agregar su sección con sus slugs.
# ─────────────────────────────────────────────────────────────────────────────

SLUG_SUBTITULOS = {

    # ── Uruguay ───────────────────────────────────────────────────────────────
    'residencia-legal-documento-especial-fronterizo':
        'Documento especial fronterizo',
    'residencia-legal-permanente':
        'Residencia permanente · Régimen general',
    'residencia-legal-temporaria':
        'Residencia temporaria · Régimen general',
    'residencia-legal-permanente-mercosur':
        'Residencia permanente · Países del MERCOSUR',
    'residencia-legal-temporaria-mercosur':
        'Residencia temporaria · Países del MERCOSUR',
    'residencia-legal-permanente-vinculo-uruguayo':
        'Residencia permanente · Vínculo con ciudadano uruguayo',
    'permiso-menor-edad-menor-viaja-sin-padres-acompanado-solo-padre':
        'Menor viaja acompañado solo por un padre',
    'permiso-menor-edad-menor-autorizacion-judicial-viaje':
        'Menor viaja con autorización judicial',
    'permiso-menor-edad-menor-bajo-regimen-tutela':
        'Menor bajo régimen de tutela',
    'permiso-menor-edad-menor-cuando-uno-padres-ha-perdido-patria-potestad':
        'Menor: un padre perdió la patria potestad',
    'permiso-menor-edad-menor-viaja-solo-cuando-uno-padres-fallecido':
        'Menor viaja solo: un padre fallecido',
    'permiso-menor-edad-menor-sometido-tutela-inau':
        'Menor bajo tutela del INAU',
    'permiso-menor-edad-menor-uno-padres-internado-centro-reclusion':
        'Menor: un padre está privado de libertad',
    'permiso-menor-edad-menor-cuando-uno-ambos-padres-residen-exterior-pais':
        'Menor: padres residen en el exterior',
    'permiso-menor-edad-cuando-uno-padres-declarado-incapaz':
        'Menor: un padre declarado incapaz',
    'permiso-menor-edad-menor-autorizado-uno-ambos-padres-mediante-carta-poder':
        'Menor autorizado mediante carta poder',
    'permiso-menor-edad-menor-cuando-padres-residen-ciudades-diferentes-dentro-territorio-nacional':
        'Menor: padres en ciudades diferentes del país',
    'permiso-menor-edad-cuando-uno-ambos-padres-son-menores-edad':
        'Menor: uno o ambos padres son menores de edad',

    # ── España ────────────────────────────────────────────────────────────────
    # España sí extrae tipo_autorizacion, pero por si acaso los slugs también
    # tienen subtítulos de respaldo.
    'estancia-por-estudios':
        'Estancia para estudios superiores o secundaria',
    'autorizacion-de-estancia-por-movilidad-de-alumnos':
        'Movilidad de alumnos (intercambio)',
    'cuenta-ajena':
        'Trabajo por cuenta ajena (empleado)',
    'cuenta-propia-/-emprendedores':
        'Trabajo por cuenta propia / Emprendedor',
    'investigadores':
        'Investigadores y científicos',
    'trabajador-altamente-cualificado':
        'Trabajador altamente cualificado (Blue Card)',
    'contrataciones-en-origen':
        'Contratación en origen (desde el país de origen)',
    'autorizacion-inicial-de-residencia-temporal-no-lucrativa':
        'Residencia temporal no lucrativa (renta propia)',
    'autorizacion-de-residencia-temporal-por-reagrupacion-familiar':
        'Reagrupación familiar',
    'autorizacion-de-residencia-independiente-de-familiares-reagrupados':
        'Residencia independiente de familiares reagrupados',
}

# ─────────────────────────────────────────────────────────────────────────────
# LÓGICA DE ENRIQUECIMIENTO
# ─────────────────────────────────────────────────────────────────────────────

def extraer_slug(url: str) -> str:
    """Extrae el slug útil de la URL, quitando el fragment (#...)."""
    url = url.split('#')[0]
    if '/tramites/' in url:
        return url.split('/tramites/')[-1].rstrip('/')
    # Para España: el último segmento del path
    return url.rstrip('/').split('/')[-1]

def generar_subtitulo(url: str, titulo: str, tipo_autorizacion) -> str:
    """
    Genera el mejor subtítulo posible para un documento.
    Prioridad:
      1. Mapa estático de slugs
      2. tipo_autorizacion (primera línea, si es breve)
      3. Capitalización del slug como fallback
    """
    slug = extraer_slug(url)

    # 1. Mapa estático
    if slug in SLUG_SUBTITULOS:
        return SLUG_SUBTITULOS[slug]

    # 2. tipo_autorizacion — usar primera línea si es corta
    if tipo_autorizacion:
        tipo_str = tipo_autorizacion if isinstance(tipo_autorizacion, str) \
                   else ' '.join(tipo_autorizacion)
        primera_linea = tipo_str.split('\n')[0].strip()
        if 10 < len(primera_linea) < 80:
            return primera_linea

    # 3. Fallback: limpiar el slug
    limpio = slug.replace('-', ' ').capitalize()
    return limpio[:80]

def normalizar_titulo(titulo: str, subtitulo: str) -> str:
    """
    Si el título es genérico (ej: 'Residencia Legal', 'Permiso para menor de edad'),
    usar el subtítulo como título principal y dejar el subtítulo vacío.
    """
    titulos_genericos = {
        'residencia legal',
        'permiso para menor de edad',
        'residencia',
        'visado',
    }
    if titulo.lower().strip() in titulos_genericos:
        return subtitulo
    return titulo

def enriquecer(data: list, pais_filter: str = None) -> list:
    resultado = []
    for registro in data:
        pais_iso = registro.get('pais_iso', '')
        if pais_filter and pais_iso.upper() != pais_filter.upper():
            resultado.append(registro)
            continue

        d = registro.get('data')
        if not d or d.get('status') != 'ok':
            resultado.append(registro)
            continue

        url     = registro.get('url', '')
        titulo  = d.get('titulo', '')
        tipo    = d.get('tipo_autorizacion')

        subtitulo = generar_subtitulo(url, titulo, tipo)
        titulo_final = normalizar_titulo(titulo, subtitulo)

        # Si el título cambió, el subtítulo pasa a ser el título original (aclaración)
        subtitulo_final = titulo if titulo_final != titulo else subtitulo

        # Mutar una copia del registro
        nuevo = dict(registro)
        nuevo['data'] = dict(d)
        nuevo['data']['titulo']    = titulo_final
        nuevo['data']['subtitulo'] = subtitulo_final

        resultado.append(nuevo)

    return resultado

def exportar_firestore(data: list) -> list:
    """Convierte al formato de documentos Firestore (igual que en scraper_v2)."""
    PAIS_INFO = {
        'ES': {'nombre': 'España',  'flag': '🇪🇸', 'regimenUe': True,  'fuente': 'inclusion.gob.es'},
        'UY': {'nombre': 'Uruguay', 'flag': '🇺🇾', 'regimenUe': False, 'fuente': 'gub.uy'},
    }
    OBJETIVO_MAP = {
        'estudios':                   ['estudiar'],
        'trabajo':                    ['trabajar'],
        'emprender':                  ['emprender'],
        'familiar':                   ['familia'],
        'residencia':                 ['residir', 'trabajar', 'estudiar', 'emprender'],
        'circunstancias_excepcionales': ['residir'],
        'nomada_digital':             ['trabajar', 'emprender'],
        'retorno':                    ['residir'],
        'documento':                  ['residir', 'trabajar', 'estudiar', 'emprender', 'familia'],
        'menores':                    ['familia', 'estudiar'],
        'otro':                       ['residir'],
    }

    docs = []
    for r in data:
        d = r.get('data')
        if not d or d.get('status') != 'ok':
            continue

        pais_iso = r.get('pais_iso', 'XX')
        info     = PAIS_INFO.get(pais_iso, {})
        cat      = d.get('categoria', 'otro')

        # Helper: normaliza campo que puede ser str o list
        def to_str(v):
            if v is None: return None
            if isinstance(v, list): return ' · '.join(str(x) for x in v) or None
            return str(v) if str(v) else None

        doc_id = f"{pais_iso}_{d['hash']}"
        doc = {
            'id':                    doc_id,
            'paisIso':               pais_iso,
            'paisNombre':            info.get('nombre', ''),
            'paisFlag':              info.get('flag', '🌍'),
            'paisRegimenUe':         info.get('regimenUe', False),
            'fuenteOficial':         info.get('fuente', ''),
            'url':                   r.get('url', ''),
            'titulo':                d.get('titulo', ''),
            'subtitulo':             d.get('subtitulo', ''),   # ← NUEVO campo
            'categoria':             cat,
            'objetivos':             OBJETIVO_MAP.get(cat, ['residir']),
            'soloPasaporteUe':       d.get('solo_pasaporte_ue', False),
            'duracion':              to_str(d.get('duracion')),
            'renovable':             d.get('renovable'),
            'tipoAutorizacion':      to_str(d.get('tipo_autorizacion')),
            'normativa':             to_str(d.get('normativa')),
            'requisitos':            d.get('requisitos') or [],
            'documentacionExigible': d.get('documentacion_exigible') or [],
            'procedimiento':         d.get('procedimiento') or [],
            'familiares':            d.get('familiares') or [],
            'prorroga':              d.get('prorroga') or [],
            'tasas':                 to_str(d.get('tasas')),
            'plazoResolucion':       to_str(d.get('plazo_resolucion')),
            'notas':                 d.get('notas_importantes') or [],
            'scrapedAt':             r.get('scraped_at', ''),
            'hash':                  d.get('hash', ''),
        }
        docs.append(doc)
    return docs

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pais',    type=str, help='Filtrar por país ISO (UY, ES)')
    parser.add_argument('--upload',  action='store_true', help='Subir a Firestore')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    if not Path(INPUT_FILE).exists():
        print(f"❌ No se encontró {INPUT_FILE}")
        return

    with open(INPUT_FILE, encoding='utf-8') as f:
        data = json.load(f)

    print(f"📥 {len(data)} registros cargados")

    enriquecido = enriquecer(data, pais_filter=args.pais)

    # Guardar JSON enriquecido
    Path(OUTPUT_FILE).write_text(
        json.dumps(enriquecido, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )
    print(f"✅ JSON enriquecido guardado: {OUTPUT_FILE}")

    # Generar Firestore
    docs = exportar_firestore(enriquecido)
    Path(FIRESTORE_FILE).write_text(
        json.dumps(docs, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )
    print(f"🔥 Firestore ready: {FIRESTORE_FILE} ({len(docs)} docs)")

    # Mostrar preview
    print("\nPreview de títulos/subtítulos:")
    for d in docs:
        if args.pais and d['paisIso'] != args.pais.upper():
            continue
        print(f"  [{d['paisIso']}] {d['titulo']}")
        if d.get('subtitulo'):
            print(f"         → {d['subtitulo']}")

    if args.upload and not args.dry_run:
        _upload_to_firestore(docs)

def _upload_to_firestore(docs):
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore as fs
    except ImportError:
        print("❌ pip install firebase-admin")
        return

    cred_path = 'serviceAccountKey.json'
    if not Path(cred_path).exists():
        print(f"❌ No se encontró {cred_path}")
        return

    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(cred_path))

    db    = fs.client()
    batch = db.batch()
    count = 0
    for doc in docs:
        ref = db.collection('migration_guides').document(doc['id'])
        batch.set(ref, doc, merge=True)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
            print(f"  Batch confirmado ({count} docs)")
    if count % 400 != 0:
        batch.commit()
    print(f"✅ {count} documentos subidos a Firestore")

if __name__ == '__main__':
    main()