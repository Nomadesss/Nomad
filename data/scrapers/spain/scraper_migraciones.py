"""
Descarga y parsea las páginas de migraciones de inclusion.gob.es.

Uso:
    python scraper_migraciones.py              # todas las URLs
    python scraper_migraciones.py --limit 3    # solo las primeras 3 (test)
    python scraper_migraciones.py --resume     # continuar si se interrumpió
"""

import json
import re
import sys
import time
import hashlib
import argparse
from pathlib import Path
from datetime import datetime, timezone
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

try:
    import requests
    from bs4 import BeautifulSoup, NavigableString, Tag
except ImportError:
    print("❌ Instalá las dependencias: pip install requests beautifulsoup4")
    sys.exit(1)


# ─────────────────────────────────────────────
# URLS
# ─────────────────────────────────────────────
URLS_ESPANA = [
    "https://www.inclusion.gob.es/web/migraciones/w/estancia-por-estudios",
    "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-de-estancia-por-movilidad-de-alumnos",
    "https://www.inclusion.gob.es/web/migraciones/w/5.-movilidad-de-estudiantes-dentro-de-la-union-europea",
    "https://www.inclusion.gob.es/web/migraciones/w/22.-nacionales-andorranos-y-sus-familiares",
    "https://www.inclusion.gob.es/web/migraciones/w/45.-desplazamiento-temporal-de-menores-extranjeros-con-fines-de-escolarizacion",
    "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-para-participacion-programa-voluntario",
    "https://www.inclusion.gob.es/web/migraciones/w/21.-autorizacion-de-residencia-para-practicas",
    "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-de-estancia-para-actividades-de-investigacion-o-formacion",
    "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-inicial-de-residencia-temporal-no-lucrativa",
    "https://www.inclusion.gob.es/en/web/migraciones/w/17.-autorizacion-de-residencia-temporal-de-la-persona-extranjera-que-ha-retornado-voluntariamente-a-su-pais",
    "https://www.inclusion.gob.es/en/web/migraciones/w/22.-nacionales-andorranos-y-sus-familiares",
    "https://www.inclusion.gob.es/en/web/migraciones/cuenta-ajena",
    "https://www.inclusion.gob.es/en/web/migraciones/cuenta-propia-/-emprendedores",
    "https://www.inclusion.gob.es/en/web/migraciones/exceptuados",
    "https://www.inclusion.gob.es/en/web/migraciones/investigadores",
    "https://www.inclusion.gob.es/en/web/migraciones/trabajador-altamente-cualificado",
    "https://www.inclusion.gob.es/en/web/migraciones/prestaciones-transnacionales-de-servicios",
    "https://www.inclusion.gob.es/en/web/migraciones/contrataciones-en-origen",
    "https://www.inclusion.gob.es/en/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0-3",
    "https://www.inclusion.gob.es/en/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0-4",
    "https://www.inclusion.gob.es/en/web/migraciones/w/43.-desplazamiento-temporal-de-menores-extranjeros-con-fines-de-tratamiento-medico",
    "https://www.inclusion.gob.es/en/web/migraciones/w/44.-desplazamiento-temporal-de-menores-extranjeros-con-fines-vacacionales",
    "https://www.inclusion.gob.es/en/web/migraciones/w/45.-desplazamiento-temporal-de-menores-extranjeros-con-fines-de-escolarizacion",
    "https://www.inclusion.gob.es/en/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0-5",
    "https://www.inclusion.gob.es/en/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0-7",
    "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-de-residencia-temporal-por-reagrupacion-familiar",
    "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-de-residencia-independiente-de-familiares-reagrupados.",
    "https://www.inclusion.gob.es/en/web/migraciones/w/37.-autorizacion-de-residencia-temporal-y-trabajo-por-colaborar-con-autor.-polic-fisc.-o-judic.-contra-redes",
    "https://www.inclusion.gob.es/en/web/migraciones/w/38.-autorizacion-de-residencia-temporal-y-trabajo-por-circunstancias-excepcionales-de-personas-extranjeras-victimas-de-trata-de-seres-humanos",
    "https://www.inclusion.gob.es/en/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0-3",
    "https://www.inclusion.gob.es/en/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0",
    "https://www.inclusion.gob.es/en/web/migraciones/w/62.-tarjeta-de-residencia-de-familiar-de-ciudadano-de-la-union-europea",
    "https://www.inclusion.gob.es/en/web/migraciones/familiar-de-persona-con-nacionalidad-espanola",
    "https://www.inclusion.gob.es/en/web/migraciones/w/36.-autorizacion-de-residencia-temporal-y-trabajo-por-circunst-excep.-por-colaborar-con-autor.adm.no-policia.-contra-redes",
    "https://www.inclusion.gob.es/en/web/migraciones/w/37.-autorizacion-de-residencia-temporal-y-trabajo-por-colaborar-con-autor.-polic-fisc.-o-judic.-contra-redes",
    "https://www.inclusion.gob.es/en/web/migraciones/w/38.-autorizacion-de-residencia-temporal-y-trabajo-por-circunstancias-excepcionales-de-personas-extranjeras-victimas-de-trata-de-seres-humanos",
    "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-laboral",
    "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-social",
    "https://www.inclusion.gob.es/en/web/migraciones/w/29.-autorizacion-de-residencia-temporal-por-circunstancias-excepcionales.-arraigo-sociolaboral.",
    "https://www.inclusion.gob.es/en/web/migraciones/w/30.-autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-socioformativo",
    "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-familiar",
    "https://www.inclusion.gob.es/en/web/migraciones/w/32.-autorizacion-residencia-temporal-por-circunstancias-excepcionales-por-razones-humanitarias",
    "https://www.inclusion.gob.es/en/web/migraciones/w/33.-autorizacion-de-residencia-temporal-por-circunst.-excep.-por-colaboracion-con-autoridades-policiales-fiscales-judiciales-o-seguridad-nacional",
    "https://www.inclusion.gob.es/en/web/migraciones/w/34.-autorizacion-residencia-temporal-por-circunst.-excepc.-por-interes-publico-o-colaboracion-con-la-admon-laboral",
    "https://www.inclusion.gob.es/en/web/migraciones/w/35.-autorizacion-de-residencia-temporal-y-trabajo-de-mujeres-extranjeras-victimas-de-violencia-de-genero",
    "https://www.inclusion.gob.es/en/web/migraciones/w/35-bis.-autorizacion-de-residencia-temporal-y-trabajo-de-mujeres-extranjeras-victimas-de-violencia-sexual",
    "https://www.inclusion.gob.es/en/web/migraciones/w/36.-autorizacion-de-residencia-temporal-y-trabajo-por-circunst-excep.-por-colaborar-con-autor.adm.no-policia.-contra-redes",
    "https://www.inclusion.gob.es/en/web/migraciones/w/37.-autorizacion-de-residencia-temporal-y-trabajo-por-colaborar-con-autor.-polic-fisc.-o-judic.-contra-redes",
    "https://www.inclusion.gob.es/en/web/migraciones/w/38.-autorizacion-de-residencia-temporal-y-trabajo-por-circunstancias-excepcionales-de-personas-extranjeras-victimas-de-trata-de-seres-humanos",
]

# ─────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────
OUTPUT_FILE   = "migraciones_extraidas.json"
PROGRESS_FILE = "progreso.json"
PAUSA_SEGUNDOS = 2        # pausa entre requests
TIMEOUT        = 20       # segundos por request
REINTENTOS     = 3        # reintentos ante error de red

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/121.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "es-ES,es;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# Secciones que buscamos en el HTML
SECCIONES = [
    "TIPO DE AUTORIZACIÓN",
    "NORMATIVA BÁSICA",
    "REQUISITOS",
    "DOCUMENTACIÓN EXIGIBLE",
    "PROCEDIMIENTO",
    "PROCEDIMIENTO INICIADO DESDE FUERA DE ESPAÑA",
    "PROCEDIMIENTO INICIADO DESDE ESPAÑA",
    "FAMILIARES",
    "PRÓRROGA DE LA AUTORIZACIÓN",
]

ALIAS = {
    "TIPO DE AUTORIZACIÓN":                         "tipo_autorizacion",
    "NORMATIVA BÁSICA":                             "normativa",
    "REQUISITOS":                                   "requisitos",
    "DOCUMENTACIÓN EXIGIBLE":                       "documentacion_exigible",
    "PROCEDIMIENTO":                                "procedimiento",
    "PROCEDIMIENTO INICIADO DESDE FUERA DE ESPAÑA": "procedimiento_exterior",
    "PROCEDIMIENTO INICIADO DESDE ESPAÑA":          "procedimiento_espana",
    "FAMILIARES":                                   "familiares",
    "PRÓRROGA DE LA AUTORIZACIÓN":                  "prorroga",
}

COMO_TEXTO = {"TIPO DE AUTORIZACIÓN", "NORMATIVA BÁSICA"}


# ─────────────────────────────────────────────
# UTILIDADES
# ─────────────────────────────────────────────
def limpiar(texto: str) -> str:
    texto = texto.replace("\xa0", " ").replace("\u200b", "")
    return re.sub(r"\s+", " ", texto).strip()

def es_texto_util(texto: str) -> bool:

    t = texto.lower()

    if len(texto) < 15:
        return False

    basura = [
        "nota:",
        "más información",
        "lista de traductores",
        "legalización",
        "traducción",
        "external link",
        "información sobre",
        "hoja informativa",
        "pincha aquí",
        "este enlace",
        "https://"
    ]

    if any(b in t for b in basura):
        return False

    return True

def es_seccion(texto: str) -> str | None:
    t = limpiar(texto).upper().strip("*. ")
    for sec in SECCIONES:
        if t == sec or t.startswith(sec):
            return sec
    return None

def log(msg: str):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")


# ─────────────────────────────────────────────
# DESCARGA
# ─────────────────────────────────────────────
def descargar(url: str) -> str | None:

    for intento in range(1, REINTENTOS + 1):

        try:

            r = requests.get(
                url,
                headers=HEADERS,
                timeout=TIMEOUT,
                verify=False
            )

            r.raise_for_status()
            r.encoding = r.apparent_encoding or "utf-8"

            return r.text

        except requests.RequestException as e:
            if intento < REINTENTOS:
                log(
                    f"  ⚠ Intento {intento}/{REINTENTOS} fallido, "
                    f"reintentando... ({e})"
                )
                time.sleep(3)
            else:
                raise

# ─────────────────────────────────────────────
# PARSER
# ─────────────────────────────────────────────
def extraer_titulo(soup: BeautifulSoup) -> str:
    div = soup.find("div", class_="m-genericContent__containerTitle")
    if div and div.find("h2"):
        return limpiar(div.find("h2").get_text())
    og = soup.find("meta", property="og:title")
    if og and og.get("content"):
        return limpiar(og["content"])
    return limpiar(soup.title.string) if soup.title else ""

def extraer_contenedor(soup: BeautifulSoup) -> Tag | None:
    return (
        soup.find("div", class_="m-genericContent__html")
        or soup.find("div", class_="journal-content-article")
        or soup.find("main")
    )

def parsear_secciones(contenedor: Tag) -> dict:
    resultado = {
        "tipo_autorizacion": None,
        "normativa": None,
        "requisitos": [],
        "documentacion_exigible": [],
        "procedimiento": [],
        "procedimiento_exterior": [],
        "procedimiento_espana": [],
        "familiares": [],
        "prorroga": [],
    }
    elementos = list(contenedor.children)

    # Detectar posición de cada encabezado
    encabezados = []
    for i, el in enumerate(elementos):
        if not isinstance(el, Tag):
            continue
        strongs = el.find_all("strong") if el.name == "p" else ([el] if el.name == "strong" else [])
        for strong in strongs:
            sec = es_seccion(strong.get_text())
            if sec:
                encabezados.append((i, sec))
                break

    # Extraer contenido entre encabezados
    for idx, (pos, nombre) in enumerate(encabezados):
        pos_fin = encabezados[idx + 1][0] if idx + 1 < len(encabezados) else len(elementos)
        bloque = elementos[pos + 1: pos_fin]
        alias = ALIAS[nombre]

        if nombre in COMO_TEXTO:
            partes = []
            for el in bloque:
                if isinstance(el, Tag):
                    t = limpiar(el.get_text())
                    if t:
                        partes.append(t)
            resultado[alias] = "\n".join(partes) or None
        else:
            items = []
            for el in bloque:
                if not isinstance(el, Tag):
                    continue
                if el.name in ("ul", "ol"):
                    for li in el.find_all("li"):
                        t = limpiar(li.get_text())
                        if t:
                            items.append(t)
                elif el.name == "p":
                    t = limpiar(el.get_text())
                    if not t:
                        continue
                    if es_seccion(t):
                        continue
                    if not es_texto_util(t):
                        continue
                    items.append(t)
            resultado[alias] = items if items else None

    return resultado

def inferir_categoria(titulo: str, tipo: str) -> str:
    texto = (titulo + " " + tipo).lower()
    if any(w in texto for w in ["estudio", "universitari", "secundaria", "formaci", "investigaci", "práctic", "voluntari"]):
        return "estudios"
    if any(w in texto for w in ["trabajo", "cuenta ajena", "cuenta propia", "laboral", "emprendedor", "altamente cualificado", "contratacion"]):
        return "trabajo"
    if any(w in texto for w in ["residencia", "arraigo", "larga duración", "no lucrativa"]):
        return "residencia"
    if any(w in texto for w in ["trata", "víctima", "violencia", "humanitari", "excepcional"]):
        return "circunstancias_excepcionales"
    if any(w in texto for w in ["familiar", "reagrupaci", "cónyuge", "nacionalidad española"]):
        return "familiar"
    if any(w in texto for w in ["menor", "escolariz", "vacacional", "médico"]):
        return "menores"
    if any(w in texto for w in ["retorno", "regreso"]):
        return "retorno"
    if any(w in texto for w in ["tarjeta", "certificado"]):
        return "documento"
    return "otro"

def deduplicar(lista):

    seen = set()

    resultado = []

    for item in lista:

        if item not in seen:

            seen.add(item)

            resultado.append(item)

    return resultado

def parsear(html: str, url: str) -> dict:

    soup = BeautifulSoup(html, "html.parser")
    titulo = extraer_titulo(soup)
    contenedor = extraer_contenedor(soup)

    if not contenedor:
        return {
            "status": "sin_contenido",
            "titulo": titulo
        }

    # extraer secciones primero
    secciones = parsear_secciones(contenedor)

    # unificar procedimientos
    procedimientos = []
    procedimientos += secciones.get("procedimiento") or []
    procedimientos += secciones.get("procedimiento_exterior") or []
    procedimientos += secciones.get("procedimiento_espana") or []
    secciones["procedimiento"] = deduplicar(procedimientos)

    # eliminar campos intermedios
    secciones.pop("procedimiento_exterior", None)
    secciones.pop("procedimiento_espana", None)

    # deduplicar listas
    for k, v in secciones.items():
        if isinstance(v, list):
            secciones[k] = deduplicar(v)

    # inferir tipo
    tipo = secciones.get("tipo_autorizacion") or titulo
    return {
        "status": "ok",
        "titulo": titulo,
        "categoria": inferir_categoria(
            titulo,
            tipo or ""
        ),
        "hash": hashlib.sha256(
            html.encode()
        ).hexdigest()[:12],
        **secciones,
    }

# ─────────────────────────────────────────────
# PROGRESO
# ─────────────────────────────────────────────
def cargar_progreso() -> set:
    if Path(PROGRESS_FILE).exists():
        return set(json.loads(Path(PROGRESS_FILE).read_text())["urls"])
    return set()

def guardar_progreso(completadas: set):
    Path(PROGRESS_FILE).write_text(
        json.dumps({"urls": list(completadas), "fecha": datetime.now().isoformat()})
    )


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit",  type=int, help="Procesar solo las primeras N URLs")
    parser.add_argument("--resume", action="store_true", help="Continuar desde donde se interrumpió")
    args = parser.parse_args()

    urls = URLS_ESPANA[:args.limit] if args.limit else URLS_ESPANA

    completadas = cargar_progreso() if args.resume else set()
    pendientes  = [u for u in urls if u not in completadas]

    if not pendientes:
        log("✅ Todo ya procesado. Usá sin --resume para re-ejecutar.")
        return

    # Cargar resultados previos si hay
    resultados = []
    if args.resume and Path(OUTPUT_FILE).exists():
        resultados = json.loads(Path(OUTPUT_FILE).read_text(encoding="utf-8"))

    log(f"🚀 {len(pendientes)} URLs a procesar ({len(completadas)} ya hechas)")

    for i, url in enumerate(pendientes, 1):
        log(f"[{i}/{len(pendientes)}] {url}")

        registro = {
            "url": url,
            "pais_iso": "ES",
            "scraped_at": datetime.now(timezone.utc).isoformat(),
            "error": None,
            "data": None,
        }

        try:
            html = descargar(url)
            data = parsear(html, url)
            registro["data"] = data

            cat   = data.get("categoria", "?")
            titulo = (data.get("titulo") or "Sin título")[:60]
            n_req  = len(data.get("requisitos") or [])
            n_doc  = len(data.get("documentacion_exigible") or [])
            log(f"  ✅ [{cat}] {titulo} — {n_req} req, {n_doc} docs")

        except Exception as e:
            registro["error"] = str(e)
            log(f"  ❌ Error: {e}")

        resultados.append(registro)
        completadas.add(url)

        # Guardar tras cada URL
        Path(OUTPUT_FILE).write_text(
            json.dumps(resultados, ensure_ascii=False, indent=2),
            encoding="utf-8"
        )
        guardar_progreso(completadas)

        if i < len(pendientes):
            time.sleep(PAUSA_SEGUNDOS)

    ok     = sum(1 for r in resultados if r.get("data") and not r.get("error"))
    errores = len(resultados) - ok
    log(f"\n{'─'*50}")
    log(f"✅ Exitosos : {ok}")
    log(f"❌ Errores  : {errores}")
    log(f"📁 Resultado: {OUTPUT_FILE}")

    if errores:
        log("URLs con error:")
        for r in resultados:
            if r.get("error"):
                log(f"  {r['url']}")


if __name__ == "__main__":
    main()