"""
scraper_border_crossings_ar.py  –  Nomad App
=============================================
Scrapea pasos fronterizos de Argentina desde dos fuentes oficiales:

  FUENTE 1 — IGN (Instituto Geográfico Nacional)
    WFS con 158+ pasos: coordenadas, tipo, provincia, país limítrofe.
    https://wms.ign.gob.ar/geoserver/ows (layer: ign:pasos_de_fronteras_internacionales)

  FUENTE 2 — Prefectura Naval Argentina
    Tabla HTML con estado en tiempo real (abierto/cerrado) y horarios.
    https://contenidosweb.prefecturanaval.gob.ar/frontera/?page=listarPuertos

Los datos de ambas fuentes se cruzan por nombre y se combinan en un
solo documento por paso, que luego se sube a Firestore /border_crossings/.

Uso:
    pip install requests beautifulsoup4 firebase-admin

    # Solo ver qué se encontraría (sin subir nada)
    python scraper_border_crossings_ar.py --dry-run

    # Subir a Firestore
    python scraper_border_crossings_ar.py --key serviceAccountKey.json

Programar para ejecutar periódicamente (ej. cada mes):
    - Windows Task Scheduler / Linux cron
    - El script usa hashing para no reescribir entradas sin cambios
"""

import argparse
import hashlib
import json
import re
import sys
import time
sys.stdout.reconfigure(encoding="utf-8")
from datetime import datetime, timezone
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("[ERR] Instalá: pip install requests beautifulsoup4")
    sys.exit(1)

# ─── URLs de las fuentes ──────────────────────────────────────────────────────

# IGN: WFS (OGC) con datos completos de pasos de fronteras internacionales
# Layer: ign:pasos_de_fronteras_internacionales
IGN_WFS_URL = (
    "https://wms.ign.gob.ar/geoserver/ows"
    "?service=WFS&version=1.0.0&request=GetFeature"
    "&typeName=ign:pasos_de_fronteras_internacionales"
    "&outputFormat=application/json"
)

# Prefectura Naval: tabla HTML con estado en tiempo real
PREFECTURA_URL = (
    "https://contenidosweb.prefecturanaval.gob.ar/frontera/?page=listarPuertos"
)

FIRESTORE_COLLECTION = "border_crossings"
OUTPUT_FILE = "border_crossings_ar.json"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "es-AR,es;q=0.9",
}

# ─── Mapeo país → ISO + flag ──────────────────────────────────────────────────

PAIS_MAP = {
    "chile":      ("CL", "Chile",    "🇨🇱"),
    "bolivia":    ("BO", "Bolivia",  "🇧🇴"),
    "paraguay":   ("PY", "Paraguay", "🇵🇾"),
    "brasil":     ("BR", "Brasil",   "🇧🇷"),
    "brazil":     ("BR", "Brasil",   "🇧🇷"),
    "uruguay":    ("UY", "Uruguay",  "🇺🇾"),
}

def resolver_pais(texto: str) -> tuple:
    t = (texto or "").lower()
    for kw, info in PAIS_MAP.items():
        if kw in t:
            return info
    return ("INT", "Internacional", "🌍")

# ─── Inferir tipo de paso ─────────────────────────────────────────────────────

def inferir_tipo(texto: str) -> str:
    t = (texto or "").lower()
    if any(w in t for w in ["aeropuerto", "aéreo", "aereo", "aeroparque"]):
        return "aereo"
    if any(w in t for w in ["fluvial", "puerto", "lacustre", "río", "rio", "arroyo"]):
        return "fluvial"
    if any(w in t for w in ["marítimo", "maritimo"]):
        return "maritimo"
    return "terrestre"

# ─── Descarga con reintentos ─────────────────────────────────────────────────

def descargar(url: str, as_json: bool = False):
    import urllib3
    urllib3.disable_warnings()
    for intento in range(1, 4):
        try:
            r = requests.get(url, headers=HEADERS, timeout=20, verify=False)
            r.raise_for_status()
            if as_json:
                return r.json()
            r.encoding = r.apparent_encoding or "utf-8"
            return r.text
        except Exception as e:
            if intento < 3:
                print(f"  [WARN] Intento {intento}/3 → {e}. Reintentando...")
                time.sleep(3)
            else:
                raise

# ─── FUENTE 1: IGN GeoJSON ────────────────────────────────────────────────────

def scrape_ign() -> list[dict]:
    """
    Descarga el layer WFS del IGN (Instituto Geográfico Nacional).
    Campos relevantes del layer ign:pasos_de_fronteras_internacionales:
      nom_pfi   → nombre oficial del paso
      pvecino   → país vecino (BOLIVIA, BRASIL, CHILE, PARAGUAY, URUGUAY)
      cruce_pfi → tipo (TERRESTRE, FLUVIAL, LACUSTRE, TERRESTRE, FLUVIAL)
      prov      → provincia argentina
      lat_pfi / lon_pfi → coordenadas (también en geometry)
      hab_migr  → habilitado para migración (SI/NO)
      autoridad → autoridad de control
    """
    print(f"[>>] IGN WFS: {IGN_WFS_URL}")
    try:
        data = descargar(IGN_WFS_URL, as_json=True)
    except Exception as e:
        print(f"  [ERR] IGN WFS falló: {e}")
        return []

    features = data.get("features", [])
    if not features:
        print("  [WARN] WFS vacío o sin features.")
        return []

    CRUCE_MAP = {
        "terrestre":          "terrestre",
        "fluvial":            "fluvial",
        "lacustre":           "fluvial",
        "terrestre, fluvial": "terrestre",
    }

    pasos = []
    for feat in features:
        props = feat.get("properties", {})
        geom  = feat.get("geometry", {})
        coords = geom.get("coordinates")

        nombre = (props.get("nom_pfi") or "").strip()
        if not nombre:
            continue

        lat = lng = None
        if coords and geom.get("type") == "Point":
            lng, lat = round(coords[0], 6), round(coords[1], 6)

        pais_raw = (props.get("pvecino") or "").strip()
        iso, pais_nombre, pais_flag = resolver_pais(pais_raw.lower())

        cruce_raw = (props.get("cruce_pfi") or "").strip().lower()
        tipo = CRUCE_MAP.get(cruce_raw, "terrestre")

        prov = (props.get("prov") or "").strip().title() or None

        servicios = []
        if (props.get("hab_migr") or "").upper() == "SI":
            servicios.append("migraciones")
        autoridad = (props.get("autoridad") or "").strip()
        if autoridad:
            servicios.append(autoridad.lower())

        pasos.append({
            "nombre":            nombre,
            "tipo":              tipo,
            "lat":               lat,
            "lng":               lng,
            "provincia":         prov,
            "fronteraConIso":    iso,
            "fronteraConNombre": pais_nombre,
            "fronteraConFlag":   pais_flag,
            "horario":           None,
            "estado":            None,
            "servicios":         servicios,
            "notas":             None,
            "fuente":            "IGN",
        })

    print(f"  [OK] {len(pasos)} pasos desde IGN WFS")
    return pasos

# ─── FUENTE 2: Prefectura Naval ───────────────────────────────────────────────

def scrape_prefectura() -> list[dict]:
    """
    Scrapea la tabla HTML de la Prefectura Naval con estado en tiempo real.
    Columnas: Nombre | Estado | Motivo cierre | País | Provincia | T.entrada | T.salida
    Solo cubre pasos fluviales/lacustres/marítimos.
    """
    print(f"[>>] Prefectura Naval: {PREFECTURA_URL}")
    try:
        html = descargar(PREFECTURA_URL)
    except Exception as e:
        print(f"  [ERR] Prefectura Naval falló: {e}")
        return []

    soup = BeautifulSoup(html, "html.parser")
    table = soup.find("table")
    if not table:
        print("  [WARN] No se encontró tabla en la página de Prefectura Naval.")
        return []

    headers = [th.get_text(strip=True).lower() for th in table.find_all("th")]

    # Mapear índices de columnas
    col = {}
    for i, h in enumerate(headers):
        if "nombre" in h:       col["nombre"] = i
        elif "estado" in h:     col["estado"] = i
        elif "motivo" in h:     col["motivo"] = i
        elif "país" in h or "pais" in h: col["pais"] = i
        elif "provincia" in h:  col["provincia"] = i
        elif "entrada" in h:    col["entrada"] = i
        elif "salida" in h:     col["salida"] = i

    pasos = []
    for tr in table.find_all("tr")[1:]:
        celdas = tr.find_all("td")
        if len(celdas) < 2:
            continue

        def cel(key: str) -> str:
            return celdas[col[key]].get_text(strip=True) if key in col and col[key] < len(celdas) else ""

        nombre = cel("nombre")
        if not nombre:
            continue

        pais_texto = cel("pais")
        iso, pais_nombre, pais_flag = resolver_pais(pais_texto or nombre)

        t_entrada = cel("entrada")
        t_salida  = cel("salida")
        horario = None
        if t_entrada or t_salida:
            horario = f"Entrada: {t_entrada} / Salida: {t_salida}".strip(" /")

        estado  = cel("estado") or None
        motivo  = cel("motivo") or None
        notas   = f"Motivo cierre: {motivo}" if motivo else None

        pasos.append({
            "nombre":           nombre,
            "tipo":             "fluvial",    # Prefectura = pasos fluviales/marítimos
            "lat":              None,
            "lng":              None,
            "provincia":        cel("provincia") or None,
            "fronteraConIso":   iso,
            "fronteraConNombre": pais_nombre,
            "fronteraConFlag":  pais_flag,
            "horario":          horario,
            "estado":           estado,
            "servicios":        ["migraciones", "prefectura"],
            "notas":            notas,
            "fuente":           "PrefecturaNaval",
        })

    print(f"  [OK] {len(pasos)} pasos desde Prefectura Naval")
    return pasos

# ─── Combinar fuentes ─────────────────────────────────────────────────────────

def normalizar_nombre(nombre: str) -> str:
    """Normaliza para comparar: minúsculas, sin acentos, sin guiones."""
    n = nombre.lower()
    for a, b in [("á","a"),("é","e"),("í","i"),("ó","o"),("ú","u"),("ñ","n")]:
        n = n.replace(a, b)
    return re.sub(r"[^a-z0-9\s]", " ", n).strip()

def combinar(ign: list[dict], prefectura: list[dict]) -> list[dict]:
    """
    Usa el IGN como fuente base (coordenadas + tipo + nombre).
    Enriquece con datos de Prefectura Naval (estado, horario) por nombre similar.
    Los pasos de Prefectura que no están en el IGN se agregan igual (sin coords).
    """
    # Índice del IGN por nombre normalizado
    ign_index = {normalizar_nombre(p["nombre"]): p for p in ign}

    combinados: dict[str, dict] = {}

    # Base: todos los del IGN
    for paso in ign:
        key = normalizar_nombre(paso["nombre"])
        combinados[key] = paso.copy()

    # Enriquecer o agregar desde Prefectura
    for pref in prefectura:
        key = normalizar_nombre(pref["nombre"])
        if key in combinados:
            # Enriquecer con estado y horario
            combinados[key]["estado"]  = pref["estado"]
            combinados[key]["horario"] = pref["horario"] or combinados[key].get("horario")
            combinados[key]["notas"]   = pref["notas"] or combinados[key].get("notas")
            if pref["servicios"]:
                existing = set(combinados[key].get("servicios", []))
                combinados[key]["servicios"] = list(existing | set(pref["servicios"]))
        else:
            # Paso solo en Prefectura (fluvial sin coords en IGN)
            combinados[key] = pref.copy()

    return list(combinados.values())

# ─── Helpers Firestore ────────────────────────────────────────────────────────

def make_id(nombre: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", normalizar_nombre(nombre)).strip("_")[:50]
    return f"AR_{slug}"

def make_hash(doc: dict) -> str:
    clean = {k: v for k, v in doc.items() if k not in ("hash", "scrapedAt")}
    return hashlib.sha256(
        json.dumps(clean, sort_keys=True, ensure_ascii=False).encode()
    ).hexdigest()[:12]

def subir_a_firestore(docs: list[dict], key_path: str):
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        print("[ERR] Instalá firebase-admin: pip install firebase-admin")
        sys.exit(1)

    if not Path(key_path).exists():
        print(f"[ERR] No se encontró {key_path}")
        sys.exit(1)

    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)

    db  = firestore.client()
    col = db.collection(FIRESTORE_COLLECTION)
    uploaded = skipped = errors = 0

    for doc in docs:
        doc_id = doc["id"]
        try:
            existing = col.document(doc_id).get()
            if existing.exists and existing.to_dict().get("hash") == doc["hash"]:
                skipped += 1
                continue
            col.document(doc_id).set(doc)
            print(f"  [OK]   {doc['nombre'][:60]}")
            uploaded += 1
        except Exception as e:
            print(f"  [ERR]  {doc.get('nombre','?')}: {e}")
            errors += 1

    print(f"\n  [OK] Subidos: {uploaded} | Sin cambios: {skipped} | Errores: {errors}")

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Scrapea y sube pasos fronterizos de Argentina a Firestore"
    )
    parser.add_argument("--key", default="serviceAccountKey.json",
                        help="Ruta al serviceAccountKey.json de Firebase")
    parser.add_argument("--dry-run", action="store_true",
                        help="Solo scrapear y mostrar resultados, sin subir a Firestore")
    args = parser.parse_args()

    scraped_at = datetime.now(timezone.utc).isoformat()
    print("-"*60)
    print(f"  Scraper pasos fronterizos AR - {scraped_at[:10]}")
    print("-"*60 + "\n")

    # 1. Scrapear ambas fuentes
    ign_pasos   = scrape_ign()
    pref_pasos  = scrape_prefectura()

    if not ign_pasos and not pref_pasos:
        print("\n[ERR] No se obtuvieron datos de ninguna fuente.")
        sys.exit(1)

    # 2. Combinar
    print(f"\n[>>] Combinando fuentes ({len(ign_pasos)} IGN + {len(pref_pasos)} Prefectura)...")
    combinados = combinar(ign_pasos, pref_pasos)
    print(f"   → {len(combinados)} pasos únicos\n")

    # 3. Construir documentos Firestore
    docs = []
    for paso in combinados:
        doc_id = make_id(paso["nombre"])
        doc = {
            "id":               doc_id,
            "paisIso":          "AR",
            "nombre":           paso["nombre"],
            "tipo":             paso.get("tipo", "terrestre"),
            "lat":              paso.get("lat"),
            "lng":              paso.get("lng"),
            "provincia":        paso.get("provincia"),
            "fronteraConIso":   paso.get("fronteraConIso", "INT"),
            "fronteraConNombre":paso.get("fronteraConNombre", "Internacional"),
            "fronteraConFlag":  paso.get("fronteraConFlag", "🌍"),
            "horario":          paso.get("horario"),
            "estado":           paso.get("estado"),       # abierto/cerrado (Prefectura)
            "horarioEstacional": False,
            "servicios":        paso.get("servicios", []),
            "notas":            paso.get("notas"),
            "fuente":           paso.get("fuente", "IGN"),
            "url":              IGN_WFS_URL if paso.get("fuente") == "IGN" else PREFECTURA_URL,
            "scrapedAt":        scraped_at,
        }
        doc["hash"] = make_hash(doc)
        docs.append(doc)

    # 4. Guardar JSON local
    Path(OUTPUT_FILE).write_text(
        json.dumps(docs, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"[>>] Guardado: {OUTPUT_FILE}")

    # 5. Mostrar resumen
    sin_coords = sum(1 for d in docs if d["lat"] is None)
    by_pais = {}
    for d in docs:
        by_pais[d["fronteraConNombre"]] = by_pais.get(d["fronteraConNombre"], 0) + 1

    print(f"\n  Total: {len(docs)} pasos | Sin coordenadas: {sin_coords}")
    print("  Por país limítrofe:")
    for pais, n in sorted(by_pais.items(), key=lambda x: -x[1]):
        print(f"    {pais:<20} {n}")

    if args.dry_run:
        print("\n=== DRY RUN — primeros 10 pasos ===")
        for d in docs[:10]:
            coords = f"({d['lat']:.4f}, {d['lng']:.4f})" if d["lat"] else "(sin coords)"
            estado = f" [{d['estado']}]" if d.get("estado") else ""
            print(f"  [{d['tipo']:<10}] {d['nombre'][:50]:<50} {d['fronteraConFlag']}{estado} {coords}")
        if len(docs) > 10:
            print(f"  ... y {len(docs)-10} más en {OUTPUT_FILE}")
        return

    # 6. Subir a Firestore
    print(f"\n[>>] Subiendo a Firestore/{FIRESTORE_COLLECTION}...")
    subir_a_firestore(docs, args.key)


if __name__ == "__main__":
    main()
