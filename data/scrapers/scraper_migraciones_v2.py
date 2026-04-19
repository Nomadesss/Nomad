"""
scraper_migraciones_v2.py
=========================
Versión 2 del scraper de información migratoria.

Mejoras sobre v1:
  · Soporte multi-país (España + Uruguay + estructura para cualquier país)
  · Inferencia de categoría expandida con mapa de objetivos del migrante
  · Campo `objetivo` (trabajar|estudiar|emprender|familia|residir|nomada)
  · Campo `requiere_pasaporte_ue` para filtrar por régimen comunitario
  · Campo `duracion` y `renovable` extraídos del texto
  · Normalización de campos para Firestore
  · Exportación directa a JSON listo para subir a Firestore
  · Modo --dry-run para probar sin guardar
  · Modo --pais para procesar solo un país

Uso:
    pip install requests beautifulsoup4
    python scraper_migraciones_v2.py                   # España + Uruguay
    python scraper_migraciones_v2.py --pais ES         # Solo España
    python scraper_migraciones_v2.py --pais UY         # Solo Uruguay
    python scraper_migraciones_v2.py --limit 5         # Solo 5 URLs (test)
    python scraper_migraciones_v2.py --resume          # Continuar scraping
    python scraper_migraciones_v2.py --export-firestore # JSON para Firestore
"""

import json
import re
import sys
sys.stdout.reconfigure(encoding="utf-8")
import time
import hashlib
import argparse
from pathlib import Path
from datetime import datetime, timezone

try:
    import requests
    from bs4 import BeautifulSoup, NavigableString, Tag
except ImportError:
    print("❌ Instalá: pip install requests beautifulsoup4")
    sys.exit(1)

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN POR PAÍS
# Estructura escalable: para agregar un país nuevo, agregás su entrada aquí.
# ─────────────────────────────────────────────────────────────────────────────

PAISES = {

    "ES": {
        "nombre": "España",
        "flag": "🇪🇸",
        "moneda": "EUR",
        "idioma_oficial": "es",
        "regimen_ue": True,   # País de la UE → régimen comunitario disponible
        "fuente_oficial": "inclusion.gob.es",
        "urls": [
            # ── ESTUDIOS ──────────────────────────────────────────────────
            "https://www.inclusion.gob.es/web/migraciones/w/estancia-por-estudios",
            "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-de-estancia-por-movilidad-de-alumnos",
            "https://www.inclusion.gob.es/web/migraciones/w/5.-movilidad-de-estudiantes-dentro-de-la-union-europea",
            "https://www.inclusion.gob.es/web/migraciones/w/21.-autorizacion-de-residencia-para-practicas",
            "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-de-estancia-para-actividades-de-investigacion-o-formacion",
            "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-para-participacion-programa-voluntario",
            "https://www.inclusion.gob.es/web/migraciones/w/58.-modificaciones-desde-autorizaciones-de-estancia-por-estudios-superiores-ensenanza-secundaria-actividades-formativas-o-formacion-sanitaria-especializada",
            # ── TRABAJO ───────────────────────────────────────────────────
            "https://www.inclusion.gob.es/en/web/migraciones/cuenta-ajena",
            "https://www.inclusion.gob.es/en/web/migraciones/investigadores",
            "https://www.inclusion.gob.es/en/web/migraciones/trabajador-altamente-cualificado",
            "https://www.inclusion.gob.es/en/web/migraciones/contrataciones-en-origen",
            "https://www.inclusion.gob.es/en/web/migraciones/prestaciones-transnacionales-de-servicios",
            "https://www.inclusion.gob.es/web/migraciones/w/aa-plantilla-hoja-informativa-no-borrar-duplicado-1",
            "https://www.inclusion.gob.es/web/migraciones/w/40.-autorizacion-de-trabajo-por-cuenta-ajena-para-trabajadores-transfronterizos",
            "https://www.inclusion.gob.es/web/migraciones/w/39.-autorizacion-de-trabajo-por-cuenta-propia-para-trabajadores-transfronterizos",
            "https://www.inclusion.gob.es/web/migraciones/w/64.-autorizacion-de-trabajo-a-penados-extranjeros-en-regimen-abierto-o-libertad-condicional",
            "https://www.inclusion.gob.es/web/migraciones/w/66.-autorizacion-inicial-de-residencia-y-trabajo-de-profesionales-altamente-cualificados",
            "https://www.inclusion.gob.es/web/migraciones/w/67.-renovacion-de-la-autorizacion-de-residencia-temporal-y-trabajo-de-profesionales-altamente-cualificados",
            "https://www.inclusion.gob.es/web/migraciones/w/24.-gestion-colectiva-de-contrataciones-en-origen",
            "https://www.inclusion.gob.es/web/migraciones/w/25.-autorizacion-de-residencia-y-trabajo-para-la-migracion-estable-gestion-colectiva-de-contrataciones-en-origen-gecco-2025-",
            "https://www.inclusion.gob.es/web/migraciones/w/26.-autorizacion-de-residencia-temporal-y-trabajo-para-actividades-de-temporada-en-migracion-circular.-gestion-colectiva-de-contrataciones-en-origen-gecco-2025-",
            # ── EMPRENDER ─────────────────────────────────────────────────
            "https://www.inclusion.gob.es/en/web/migraciones/cuenta-propia-/-emprendedores",
            # ── RESIDENCIA ────────────────────────────────────────────────
            "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-inicial-de-residencia-temporal-no-lucrativa",
            "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-laboral",
            "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-social",
            "https://www.inclusion.gob.es/web/migraciones/w/29.-autorizacion-de-residencia-temporal-por-circunstancias-excepcionales.-arraigo-sociolaboral.",
            "https://www.inclusion.gob.es/en/web/migraciones/w/30.-autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-socioformativo",
            "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-residencia-temporal-por-circunstancias-excepcionales.-arraigo-familiar",
            "https://www.inclusion.gob.es/web/migraciones/w/hoja-4-bis-acceso-al-empleo-de-las-personas-titulares-de-una-autorizacion-de-estancia-de-larga-duracion-por-estudios-movilidad-de-alumnos-servicios-de-voluntariado-o-actividades-formativas",
            "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-inicial-de-residencia-temporal-y-trabajo-por-cuenta-ajena-hi-16-",
            "https://www.inclusion.gob.es/web/migraciones/w/18.-autorizacion-de-residencia-temporal-de-familiares-de-personas-con-nacionalidad-espanola",
            "https://www.inclusion.gob.es/web/migraciones/w/23.-autorizacion-de-residencia-temporal-y-trabajo-para-actividades-de-temporada",
            "https://www.inclusion.gob.es/web/migraciones/w/autorizacion-inicial-de-residencia-temporal-y-trabajo-por-cuenta-propia",
            "https://www.inclusion.gob.es/web/migraciones/w/20.-autorizacion-de-residencia-para-busqueda-de-empleo-o-inicio-de-proyecto-empresarial",
            "https://www.inclusion.gob.es/web/migraciones/w/68.-autorizacion-de-residencia-temporal-y-trabajo-para-investigacion",
            "https://www.inclusion.gob.es/web/migraciones/w/15.-renovacion-de-la-autorizacion-de-residencia-temporal-y-trabajo-por-cuenta-propia",
            "https://www.inclusion.gob.es/web/migraciones/w/renovacion-de-la-autorizacion-de-residencia-temporal-no-lucrativa",
            "https://www.inclusion.gob.es/web/migraciones/w/renovacion-de-la-autorizacion-de-residencia-temporal-y-trabajo-por-cuenta-ajena",
            "https://www.inclusion.gob.es/web/migraciones/w/55.-modificacion-desde-situaciones-de-autorizaciones-de-residencia-temporal-que-habilitan-a-trabajar",
            "https://www.inclusion.gob.es/web/migraciones/w/55-bis.-modificaciones-desde-situaciones-de-residencia-que-no-habilitaban-a-trabajar",
            "https://www.inclusion.gob.es/web/migraciones/w/49.-autorizacion-de-residencia-de-larga-duracion-nacional",
            # ── FAMILIA ───────────────────────────────────────────────────
            "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-de-residencia-temporal-por-reagrupacion-familiar",
            "https://www.inclusion.gob.es/en/web/migraciones/w/autorizacion-de-residencia-independiente-de-familiares-reagrupados.",
            "https://www.inclusion.gob.es/en/web/migraciones/familiar-de-persona-con-nacionalidad-espanola",
            "https://www.inclusion.gob.es/web/migraciones/w/19.-residencia-independiente-de-las-personas-que-tienen-o-han-tenido-vinculos-familiares-con-una-persona-de-nacionalidad-espanola",
            "https://www.inclusion.gob.es/web/migraciones/w/renovacion-de-la-autorizacion-de-residencia-por-reagrupacion-familiar.",
            "https://www.inclusion.gob.es/web/migraciones/w/57.-modificacion-desde-tarjeta-de-residencia-de-familiar-de-ciudadano-de-la-union-o-de-autorizacion-de-familiar-de-persona-con-nacionalidad-espanola",
            # ── RÉGIMEN COMUNITARIO (PASAPORTE UE) ────────────────────────
            "https://www.inclusion.gob.es/en/web/migraciones/w/62.-tarjeta-de-residencia-de-familiar-de-ciudadano-de-la-union-europea",
            "https://www.inclusion.gob.es/web/migraciones/w/22.-nacionales-andorranos-y-sus-familiares",
            "https://www.inclusion.gob.es/web/migraciones/w/69.-movilidad-de-residencia-para-investigador-ue-concedido-en-un-estado-miembro-de-la-union-europea-distinto-a-espana",
            "https://www.inclusion.gob.es/web/migraciones/w/50.-autorizacion-de-residencia-de-larga-duracion-ue",
            "https://www.inclusion.gob.es/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue",
            "https://www.inclusion.gob.es/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0",
            "https://www.inclusion.gob.es/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0-1",
            "https://www.inclusion.gob.es/web/migraciones/w/51.-residencia-de-larga-duracion-en-espana-del-residente-de-larga-duracion-ue-en-otro-eemm-de-la-ue-duplicar-0-2",
            "https://www.inclusion.gob.es/web/migraciones/w/63.-tarjeta-de-residencia-permanente-de-familiar-de-ciudadano-de-la-union-europea",
            "https://www.inclusion.gob.es/web/migraciones/w/65.-certificado-de-registro-de-ciudadano-de-la-union-europea",
            # ── NÓMADA DIGITAL ────────────────────────────────────────────
            # (España aprobó Ley de Startups 2023 con visa nómada digital)
            # URL oficial pendiente de estabilización — se agrega cuando esté activa
            # ── CIRCUNSTANCIAS EXCEPCIONALES ──────────────────────────────
            "https://www.inclusion.gob.es/en/web/migraciones/w/32.-autorizacion-residencia-temporal-por-circunstancias-excepcionales-por-razones-humanitarias",
            "https://www.inclusion.gob.es/en/web/migraciones/w/35.-autorizacion-de-residencia-temporal-y-trabajo-de-mujeres-extranjeras-victimas-de-violencia-de-genero",
        ],
        "secciones": [
            "TIPO DE AUTORIZACIÓN",
            "NORMATIVA BÁSICA",
            "REQUISITOS",
            "DOCUMENTACIÓN EXIGIBLE",
            "PROCEDIMIENTO",
            "PROCEDIMIENTO INICIADO DESDE FUERA DE ESPAÑA",
            "PROCEDIMIENTO INICIADO DESDE ESPAÑA",
            "FAMILIARES",
            "PRÓRROGA DE LA AUTORIZACIÓN",
        ],
        "alias": {
            "TIPO DE AUTORIZACIÓN":                         "tipo_autorizacion",
            "NORMATIVA BÁSICA":                             "normativa",
            "REQUISITOS":                                   "requisitos",
            "DOCUMENTACIÓN EXIGIBLE":                       "documentacion_exigible",
            "PROCEDIMIENTO":                                "procedimiento",
            "PROCEDIMIENTO INICIADO DESDE FUERA DE ESPAÑA": "procedimiento_exterior",
            "PROCEDIMIENTO INICIADO DESDE ESPAÑA":          "procedimiento_espana",
            "FAMILIARES":                                   "familiares",
            "PRÓRROGA DE LA AUTORIZACIÓN":                  "prorroga",
        },
        "como_texto": {"TIPO DE AUTORIZACIÓN", "NORMATIVA BÁSICA"},
        "contenedor_css": [
            "div.m-genericContent__html",
            "div.journal-content-article",
            "main",
        ],
    },

    "AR": {
        "nombre": "Argentina",
        "flag": "🇦🇷",
        "moneda": "ARS",
        "idioma_oficial": "es",
        "regimen_ue": False,
        "fuente_oficial": "argentina.gob.ar/interior/migraciones",
        "urls": [
            # ── RESIDENCIA / MERCOSUR ─────────────────────────────────────────
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-refugiado",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-estudiante",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-academico",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-por-tratamiento-medico",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-religioso",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-deportista",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-temporaria-como-cientifico-yo-personal",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-pensionado",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-rentista",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-como-trabajador-migrante",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-por-nacionalidad-mercosur",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-rentista",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-pensionado",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-trabajador-migrante",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-cientifico-yo-personal-especializado-yo-personal-de",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-deportista-yo-artista",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-religioso",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-paciente-bajo-tratamiento-medico",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-academicos",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-estudiante",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-como-asiladoa-y-refugiadoa",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-por-razones-humanitarias",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-temporaria-por-reunificacion-familiar",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-transitoria-como-academico",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-transitoria-por-tratamiento-medico",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-transitoria-como-estudiante",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-transitoria-especial-para-trabajar-en-la-industria-del-cine",
            "https://www.argentina.gob.ar/servicio/obtener-una-autorizacion-de-trabajo-transitoria",
            "https://www.argentina.gob.ar/servicio/obtener-una-residencia-transitoria-como-nomada-digital",
            # ── TURISMO ──────────────────────────────────────────────────────
            "https://www.argentina.gob.ar/migraciones/turistas",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-para-nacionalidades-mercosur",
            # ── TRABAJO ──────────────────────────────────────────────────────
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-negocios",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-nomadas-digitales",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-participantes-de-programas-de-intercambio-cultural-o-de",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-para-realizar-tareas-remuneradas-o-no-en",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-para-realizar-negocios",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-para-participantes-de-programas-de-intercambio",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-como-cientifico-personal-especializado-y-personal",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-como-artista-yo-deportista",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-como-religioso",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-como-trabajadores-contratados",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-transitoria-como-nomada-digital",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-transitoria-especial-para-desarrollar-actividades",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-transitoria-especial-para-realizar-tareas-remuneradas-o",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-transitoria-especial-para-realizar-negocios-inversiones",
            "https://www.argentina.gob.ar/servicio/obtener-una-una-prorroga-de-residencia-transitoria-especial-para-trabajar-en-la-industria",
            # ── ESTUDIOS ─────────────────────────────────────────────────────
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-ferias-y-estudio-de-mercado",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-tareas-remuneradas-o-no-en-el-campo-cientifico",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-participantes-de-programas-de-intercambio-estudiantil",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-estudiante-internacional-de-movilidad",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-becarios",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-pasantes",
            "https://www.argentina.gob.ar/servicio/tramitacion-de-ingreso-electronica-estudiantes-de-ensenanza-no-oficial",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-para-academicos",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-como-becario",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-como-pasante",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-para-estudiantes-del-sistema-de-ensenanza-no",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-para-miembros-de-un-programa-de-intercambio",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-transitorio-como-estudiante-internacional-de-movilidad",
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-como-estudiante-de-ensenanza-oficial",
            "https://www.argentina.gob.ar/servicio/obtener-prorroga-de-residencia-transitoria-como-estudiante",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-una-residencia-transitoria-por-tratamiento-medico",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-una-residencia-transitoria-como-academico",
            # ── FAMILIA ──────────────────────────────────────────────────────
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-por-reunificacion-familiar-padre-hijo-conyuge",
            "https://www.argentina.gob.ar/servicio/permiso-de-ingreso-permanente",
            "https://www.argentina.gob.ar/servicio/obtener-una-prorroga-de-residencia-temporaria-por-reunificacion-familiar",
            "https://www.argentina.gob.ar/servicio/radicaciones-residencia-permanente",
            "https://www.argentina.gob.ar/servicio/autorizacion-de-viaje-para-menores-de-edad",
            # ── RENTISTA / PENSIONADO ────────────────────────────────────────
            "https://www.argentina.gob.ar/servicio/obtener-un-permiso-de-ingreso-temporario-como-rentista-o-pensionado",
        ],
        # argentina.gob.ar/servicio/ usa headings: ¿Qué necesito? ¿Cómo hago? ¿Cuál es el costo? Vigencia
        "secciones": [
            "REQUISITOS",
            "¿QUÉ NECESITO?",
            "QUÉ NECESITO",
            "¿CÓMO HAGO?",
            "CÓMO HAGO",
            "¿CÓMO SE HACE?",
            "CÓMO SE HACE",
            "PASOS",
            "¿CUÁL ES EL COSTO?",
            "CUÁL ES EL COSTO",
            "COSTOS",
            "VIGENCIA",
            "PLAZOS",
            "¿A QUIÉN ESTÁ DIRIGIDO?",
            "A QUIÉN ESTÁ DIRIGIDO",
            "¿DÓNDE Y CUÁNDO SE REALIZA?",
            "DÓNDE Y CUÁNDO SE REALIZA",
            "ORGANISMOS INTERVINIENTES",
            "FAMILIAS",
        ],
        "alias": {
            "REQUISITOS":                           "requisitos",
            "¿QUÉ NECESITO?":                       "documentacion_exigible",
            "QUÉ NECESITO":                         "documentacion_exigible",
            "¿CÓMO HAGO?":                          "procedimiento",
            "CÓMO HAGO":                            "procedimiento",
            "¿CÓMO SE HACE?":                       "procedimiento",
            "CÓMO SE HACE":                         "procedimiento",
            "PASOS":                                "procedimiento",
            "¿CUÁL ES EL COSTO?":                   "tasas",
            "CUÁL ES EL COSTO":                     "tasas",
            "COSTOS":                               "tasas",
            "VIGENCIA":                             "plazo_resolucion",
            "PLAZOS":                               "plazo_resolucion",
            "¿A QUIÉN ESTÁ DIRIGIDO?":              "descripcion",
            "A QUIÉN ESTÁ DIRIGIDO":                "descripcion",
            "¿DÓNDE Y CUÁNDO SE REALIZA?":          "procedimiento",
            "DÓNDE Y CUÁNDO SE REALIZA":            "procedimiento",
            "ORGANISMOS INTERVINIENTES":            "notas_importantes",
            "FAMILIAS":                             "familiares",
        },
        "como_texto": {"¿CUÁL ES EL COSTO?", "CUÁL ES EL COSTO", "COSTOS", "VIGENCIA", "PLAZOS"},
        "contenedor_css": [
            "main#contenido",
            "div.entry-content",
            "article",
            "main",
            "div.portlet-body",
            "div.journal-content-article",
        ],
    },

    "UY": {
        "nombre": "Uruguay",
        "flag": "🇺🇾",
        "moneda": "UYU",
        "idioma_oficial": "es",
        "regimen_ue": False,
        "fuente_oficial": "gub.uy",
        "urls": [
            # ── FRONTERIZO ───────────────────────────────────────────────────
            "https://www.gub.uy/tramites/residencia-legal-documento-especial-fronterizo#contenido-seleccion",
            # ── RESIDENCIA ────────────────────────────────────────────────
            "https://www.gub.uy/tramites/residencia-legal-permanente#contenido-seleccion",
            "https://www.gub.uy/tramites/residencia-legal-temporaria#contenido-seleccion",
            # ── MERCOSUR ────────────────────────────────────────────────
            "https://www.gub.uy/tramites/residencia-legal-permanente-mercosur#contenido-seleccion",
            "https://www.gub.uy/tramites/residencia-legal-temporaria-mercosur#contenido-seleccion",
            # ── FAMILIA ────────────────────────────────────
            "https://www.gub.uy/tramites/residencia-legal-permanente-vinculo-uruguayo#contenido-seleccion",
            # ── MENOR DE EDAD ───────────────────────────────────────────────────
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-viaja-sin-padres-acompanado-solo-padre#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-autorizacion-judicial-viaje#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-bajo-regimen-tutela#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-cuando-uno-padres-ha-perdido-patria-potestad#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-viaja-solo-cuando-uno-padres-fallecido#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-sometido-tutela-inau#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-uno-padres-internado-centro-reclusion#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-cuando-uno-ambos-padres-residen-exterior-pais#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-cuando-uno-padres-declarado-incapaz#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-autorizado-uno-ambos-padres-mediante-carta-poder#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-menor-cuando-padres-residen-ciudades-diferentes-dentro-territorio-nacional#contenido-seleccion",
            "https://www.gub.uy/tramites/permiso-menor-edad-cuando-uno-ambos-padres-son-menores-edad#contenido-seleccion",
        ],
        # Uruguay tiene estructura web diferente — parser genérico por headings
        "secciones": [
            "REQUISITOS",
            "QUÉ SE NECESITA",
            "CÓMO SE HACE",
            "DÓNDE Y CUÁNDO SE REALIZA",
            "COSTOS",
            "PLAZO"
        ],
        "alias": {
            "REQUISITOS":                "requisitos",
            "QUÉ SE NECESITA":           "documentacion_exigible",
            "CÓMO SE HACE":              "procedimiento",
            "DÓNDE Y CUÁNDO SE REALIZA": "procedimiento",
            "COSTOS":                    "tasas",
            "PLAZO":                     "plazo_resolucion",
        },
        "como_texto": set(),
        "contenedor_css": [
            "main#contenido",
            "main",
            "div.portlet-body",
            "div.journal-content-article",
            "article",
            "div.content",
        ],
    },
}

# ─────────────────────────────────────────────────────────────────────────────
# MAPEO CATEGORÍA → OBJETIVO DEL MIGRANTE
# Permite filtrar en la app según lo que respondió el usuario en onboarding.
# ─────────────────────────────────────────────────────────────────────────────

OBJETIVO_POR_CATEGORIA = {

    # Objetivo principal claro
    "estudios": ["estudiar"],
    "trabajo": ["trabajar"],
    "emprender": ["emprender"],
    "familiar": ["familia"],
    "nomada_digital": ["nomada"],
    # Residencias suelen permitir múltiples caminos
    "residencia": [
        "residir",
        "trabajar",
        "estudiar",
        "emprender"
    ],
    # Casos excepcionales muchas veces permiten trabajar luego
    "circunstancias_excepcionales": [
        "residir",
        "trabajar"
    ],
    # Documentos base → necesarios para casi todo
    "documento": [
        "trabajar",
        "estudiar",
        "residir",
        "emprender",
        "familia",
        "nomada"
    ],
    "menores": [
        "familia",
        "estudiar"
    ],
    "retorno": [
        "residir"
    ],
    # fallback
    "otro": [
        "residir",
        "trabajar"
    ],
}

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN GENERAL
# ─────────────────────────────────────────────────────────────────────────────

OUTPUT_FILE   = "migraciones_v2.json"
PROGRESS_FILE = "progreso_v2.json"
FIRESTORE_FILE = "firestore_migration_data.json"
PAUSA_SEGUNDOS = 2
TIMEOUT        = 20
REINTENTOS     = 3

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "es-ES,es;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# ─────────────────────────────────────────────────────────────────────────────
# UTILIDADES
# ─────────────────────────────────────────────────────────────────────────────

def limpiar(texto: str) -> str:
    texto = texto.replace("\xa0", " ").replace("\u200b", "").replace("\r", "")
    return re.sub(r"\s+", " ", texto).strip()

def es_texto_util(texto: str) -> bool:
    t = texto.lower()
    if len(texto) < 15:
        return False
    basura = [
        "nota:", "más información", "lista de traductores",
        "pincha aquí", "este enlace", "https://", "hoja informativa",
        "external link", "información sobre",
    ]
    return not any(b in t for b in basura)

def deduplicar(lista: list) -> list:
    seen, resultado = set(), []
    for item in lista:
        if item not in seen:
            seen.add(item)
            resultado.append(item)
    return resultado

def log(msg: str, nivel: str = "INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [{nivel}] {msg}")

# ─────────────────────────────────────────────────────────────────────────────
# DESCARGA
# ─────────────────────────────────────────────────────────────────────────────

def descargar(url: str) -> str:
    import urllib3
    urllib3.disable_warnings()
    for intento in range(1, REINTENTOS + 1):
        try:
            r = requests.get(url, headers=HEADERS, timeout=TIMEOUT, verify=False)
            r.raise_for_status()
            r.encoding = r.apparent_encoding or "utf-8"
            return r.text
        except requests.RequestException as e:
            if intento < REINTENTOS:
                log(f"  Intento {intento}/{REINTENTOS} fallido, reintentando... ({e})", "WARN")
                time.sleep(3)
            else:
                raise

# ─────────────────────────────────────────────────────────────────────────────
# PARSER
# ─────────────────────────────────────────────────────────────────────────────

def extraer_titulo(soup: BeautifulSoup) -> str:
    # og:title is the most specific (contains the actual page title, not site-wide header)
    og = soup.find("meta", property="og:title")
    if og and og.get("content"):
        t = limpiar(og["content"])
        # Strip trailing site name (e.g. "Obtener residencia | Argentina.gob.ar")
        for sep in [" | ", " - "]:
            if sep in t:
                t = t.split(sep)[0].strip()
        if t:
            return t
    for selector in [
        ("div", {"class": "m-genericContent__containerTitle"}),
        ("h2", {"class": "Page-title"}),
        ("h1", {}),
        ("h2", {}),
    ]:
        el = soup.find(selector[0], selector[1])
        if el:
            t = limpiar(el.get_text())
            if t:
                return t
    return limpiar(soup.title.string) if soup.title else ""

def encontrar_contenedor(soup: BeautifulSoup, selectores_css: list) -> Tag | None:
    for selector in selectores_css:
        if "#" in selector:
            tag, el_id = selector.split("#")
            el = soup.find(tag, id=el_id)
        else:
            tag, *attrs_list = selector.split(".")
            if attrs_list:
                el = soup.find(tag, class_=" ".join(attrs_list))
            else:
                el = soup.find(tag)
        if el:
            return el
    return None

def es_encabezado_seccion(texto: str, secciones: list) -> str | None:
    t = limpiar(texto).upper().replace("¿", "").replace("?", "").strip("*. :")
    for sec in secciones:
        if t == sec or t.startswith(sec):
            return sec
    return None

def parsear_secciones_genericas(contenedor: Tag, config: dict) -> dict:
    secciones    = config["secciones"]
    alias        = config["alias"]
    como_texto   = config["como_texto"]

    resultado = {v: None for v in alias.values()}
    for v in alias.values():
        if v not in resultado:
            resultado[v] = []

    elementos = [el for el in contenedor.children if isinstance(el, Tag)]

    # Detectar encabezados por <strong>, <h2>, <h3>, <h4>
    encabezados = []
    for i, el in enumerate(elementos):
        candidatos = []
        if el.name in ("h2", "h3", "h4"):
            candidatos = [el]
        elif el.name == "p":
            candidatos = el.find_all("strong")
        elif el.name == "strong":
            candidatos = [el]

        for cand in candidatos:
            sec = es_encabezado_seccion(cand.get_text(), secciones)
            if sec:
                encabezados.append((i, sec))
                break

    for idx, (pos, nombre) in enumerate(encabezados):
        pos_fin = encabezados[idx + 1][0] if idx + 1 < len(encabezados) else len(elementos)
        bloque  = elementos[pos + 1 : pos_fin]
        clave   = alias.get(nombre)
        if not clave:
            continue

        if nombre in como_texto:
            partes = [limpiar(el.get_text()) for el in bloque if isinstance(el, Tag) and limpiar(el.get_text())]
            resultado[clave] = "\n".join(partes) or None
        else:
            items = []
            for el in bloque:
                if el.name in ("ul", "ol"):
                    for li in el.find_all("li"):
                        t = limpiar(li.get_text())
                        if t:
                            items.append(t)
                elif el.name == "p":
                    t = limpiar(el.get_text())
                    if t and not es_encabezado_seccion(t, secciones) and es_texto_util(t):
                        items.append(t)
            resultado[clave] = deduplicar(items) if items else None

    return resultado

def parsear_secciones_argentina(contenedor: Tag, config: dict) -> dict:
    """
    Parser específico para argentina.gob.ar/servicio/.
    Estructura: article > div.row > div.col-md-12 > div.media.m-y-4
    Cada div.media.m-y-4 contiene un <h2> seguido del contenido de esa sección.
    """
    alias      = config["alias"]
    como_texto = config["como_texto"]
    secciones  = config["secciones"]
    resultado  = {v: None for v in alias.values()}

    # Buscar las secciones media dentro de cualquier nivel del contenedor
    media_divs = contenedor.select("div.media.m-y-4")
    if not media_divs:
        # Fallback: buscar todos los h2 directamente
        return parsear_secciones_genericas(contenedor, config)

    for div in media_divs:
        h2 = div.find("h2")
        if not h2:
            continue
        nombre = es_encabezado_seccion(h2.get_text(), secciones)
        if not nombre:
            continue
        clave = alias.get(nombre)
        if not clave:
            continue

        # Extraer contenido del div (sin el h2 ni iconos <i>)
        items = []
        for child in div.children:
            if not isinstance(child, Tag):
                continue
            if child.name in ("h2", "i"):
                continue
            if child.name in ("ul", "ol"):
                for li in child.find_all("li"):
                    t = limpiar(li.get_text(separator=" "))
                    if t and es_texto_util(t):
                        items.append(t)
            elif child.name in ("p", "div"):
                # Recurse into nested divs/p for text
                for seg in child.find_all(["p", "li"]) or [child]:
                    t = limpiar(seg.get_text(separator=" "))
                    if t and es_texto_util(t) and not es_encabezado_seccion(t, secciones):
                        items.append(t)

        items = deduplicar(items)
        if nombre in como_texto:
            resultado[clave] = "\n".join(items) or None
        else:
            resultado[clave] = items or None

    return resultado

def extraer_textos_uy(nodo: Tag) -> list:
    """Helper recursivo para extraer textos esquivando duplicados por anidación."""
    textos = []
    if nodo.name in ["ul", "ol"]:
        for li in nodo.find_all("li", recursive=False):
            t = limpiar(li.get_text(separator=" "))
            if t: textos.append(t)
    elif nodo.name == "p":
        t = limpiar(nodo.get_text(separator=" "))
        if t: textos.append(t)
    else:
        for hijo in nodo.children:
            if isinstance(hijo, Tag):
                textos.extend(extraer_textos_uy(hijo))
    return textos

def parsear_secciones_uruguay(contenedor: Tag, config: dict) -> dict:
    """Parseador específico para Uruguay que maneja doms muy anidados."""
    alias = config["alias"]
    resultado = {v: [] for v in set(alias.values())}

    # Ubicar todas las etiquetas de título a lo largo del documento entero
    encabezados = contenedor.find_all(["h2", "h3", "h4"])
    
    for h in encabezados:
        texto_h = limpiar(h.get_text()).upper().replace("¿", "").replace("?", "").strip("*. :")
        matched_sec = None
        for sec in config["secciones"]:
            if texto_h == sec or texto_h.startswith(sec):
                matched_sec = sec
                break

        if matched_sec:
            clave = alias[matched_sec]
            # Extraer contenido de los elementos hermanos posteriores hasta el siguiente título
            hermanos = h.find_next_siblings()
            for hermano in hermanos:
                if hermano.name in ["h2", "h3", "h4"]:
                    break
                textos = extraer_textos_uy(hermano)
                resultado[clave].extend(textos)

    # Limpiar y convertir a None si está vacío
    for k in resultado:
        if resultado[k]:
            resultado[k] = deduplicar(resultado[k])
        else:
            resultado[k] = None

    return resultado

def inferir_categoria(titulo: str, tipo: str, pais_iso: str) -> str:
    texto = (titulo + " " + (tipo or "")).lower()
    if any(w in texto for w in ["estudio", "universitari", "secundaria", "formaci", "investigaci", "práctic", "voluntari", "educaci"]):
        return "estudios"
    if any(w in texto for w in ["nómada digital", "nomada digital", "startup", "teletrabajo"]):
        return "nomada_digital"
    if any(w in texto for w in ["trabajo", "cuenta ajena", "laboral", "empleo", "contratacion", "altamente cualificado"]):
        return "trabajo"
    if any(w in texto for w in ["cuenta propia", "emprendedor", "inversor", "inversión", "empresa"]):
        return "emprender"
    if any(w in texto for w in ["familiar", "reagrupaci", "cónyuge", "hijo", "nacional"]):
        return "familiar"
    if any(w in texto for w in ["residencia", "arraigo", "larga duración", "no lucrativa", "permanente", "temporaria", "legal"]):
        return "residencia"
    if any(w in texto for w in ["trata", "víctima", "violencia", "humanitari", "excepcional", "asilo", "refugio", "protección"]):
        return "circunstancias_excepcionales"
    if any(w in texto for w in ["menor", "escolariz", "vacacional", "tutela"]):
        return "menores"
    if any(w in texto for w in ["retorno", "regreso"]):
        return "retorno"
    if any(w in texto for w in ["tarjeta", "apostil", "pasaporte", "documento", "certificado", "partida"]):
        return "documento"
    if any(w in texto for w in ["visa", "visado", "estancia"]):
        return "residencia"
    return "otro"

def extraer_duracion(texto: str) -> str | None:
    """Extrae la duración de la autorización del texto libre."""
    if not texto:
        return None
    patrones = [
        r"(\d+)\s*año[s]?",
        r"(\d+)\s*mes[es]*",
        r"(\d+)\s*meses",
        r"duración.*?(\d+)",
        r"vigencia.*?(\d+)",
    ]
    for p in patrones:
        m = re.search(p, texto.lower())
        if m:
            return m.group(0).strip()
    return None

def es_renovable(texto: str) -> bool | None:
    if not texto:
        return None
    t = texto.lower()
    if any(w in t for w in ["renovable", "prórroga", "renovación", "puede renovarse", "prorrogable"]):
        return True
    if any(w in t for w in ["no renovable", "no es renovable", "no admite"]):
        return False
    return None

def requiere_solo_pasaporte_ue(texto: str) -> bool:
    """Detecta si la autorización es exclusiva del régimen comunitario (pasaporte UE)."""
    if not texto:
        return False
    t = texto.lower()
    return any(w in t for w in [
        "ciudadano de la unión", "régimen comunitario", "ciudadano ue",
        "nacional ue", "familiar de ciudadano", "espacio económico europeo",
    ])

def parsear(html: str, url: str, pais_iso: str, config: dict) -> dict:
    soup       = BeautifulSoup(html, "html.parser")
    titulo     = extraer_titulo(soup)
    contenedor = encontrar_contenedor(soup, config["contenedor_css"])

    if not contenedor:
        return {"status": "sin_contenido", "titulo": titulo}

    if pais_iso == "UY":
        secciones = parsear_secciones_uruguay(contenedor, config)
    elif pais_iso == "AR":
        secciones = parsear_secciones_argentina(contenedor, config)
    else:
        secciones = parsear_secciones_genericas(contenedor, config)

    # Unificar procedimientos si hay variantes
    procedimientos = []
    for k in ("procedimiento", "procedimiento_exterior", "procedimiento_espana"):
        v = secciones.pop(k, None)
        if isinstance(v, list):
            procedimientos += v
        elif isinstance(v, str) and v:
            procedimientos.append(v)
    secciones["procedimiento"] = deduplicar(procedimientos) or None

    tipo      = secciones.get("tipo_autorizacion") or titulo
    categoria = inferir_categoria(titulo, tipo or "", pais_iso)

    return {
        "status":            "ok",
        "titulo":            titulo,
        "categoria":         categoria,
        "objetivos":         OBJETIVO_POR_CATEGORIA.get(categoria, ["residir"]),
        "solo_pasaporte_ue": requiere_solo_pasaporte_ue(tipo or titulo),
        "duracion":          extraer_duracion(tipo or ""),
        "renovable":         es_renovable(tipo or ""),
        "hash":              hashlib.sha256(html.encode()).hexdigest()[:12],
        **secciones,
    }

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTACIÓN A FIRESTORE
# ─────────────────────────────────────────────────────────────────────────────

def exportar_firestore(resultados: list) -> list:
    """
    Convierte los resultados al formato de documentos Firestore.
    Cada documento queda listo para subir a la colección
    /migration_guides/{pais_iso}_{hash}
    """
    docs = []
    for r in resultados:
        if r.get("error") or not r.get("data"):
            continue
        d = r["data"]
        if d.get("status") != "ok":
            continue

        pais_iso = r.get("pais_iso", "XX")
        config   = PAISES.get(pais_iso, {})

        doc_id = f"{pais_iso}_{d['hash']}"
        doc = {
            "id":                   doc_id,
            "paisIso":              pais_iso,
            "paisNombre":           config.get("nombre", ""),
            "paisFlag":             config.get("flag", ""),
            "paisRegimenUe":        config.get("regimen_ue", False),
            "fuenteOficial":        config.get("fuente_oficial", ""),
            "url":                  r["url"],
            "titulo":               d.get("titulo", ""),
            "categoria":            d.get("categoria", "otro"),
            "objetivos":            d.get("objetivos", []),
            "soloPasaporteUe":      d.get("solo_pasaporte_ue", False),
            "duracion":             d.get("duracion"),
            "renovable":            d.get("renovable"),
            "tipoAutorizacion":     d.get("tipo_autorizacion"),
            "normativa":            d.get("normativa"),
            "requisitos":           d.get("requisitos") or [],
            "documentacionExigible": d.get("documentacion_exigible") or [],
            "procedimiento":        d.get("procedimiento") or [],
            "familiares":           d.get("familiares") or [],
            "prorroga":             d.get("prorroga") or [],
            "tasas":                d.get("tasas"),
            "plazoResolucion":      d.get("plazo_resolucion"),
            "notas":                d.get("notas_importantes") or [],
            "scrapedAt":            r.get("scraped_at", ""),
            "hash":                 d.get("hash", ""),
        }
        docs.append(doc)

    return docs

# ─────────────────────────────────────────────────────────────────────────────
# PROGRESO
# ─────────────────────────────────────────────────────────────────────────────

def cargar_progreso() -> set:
    if Path(PROGRESS_FILE).exists():
        data = json.loads(Path(PROGRESS_FILE).read_text())
        return set(data.get("urls", []))
    return set()

def guardar_progreso(completadas: set):
    Path(PROGRESS_FILE).write_text(
        json.dumps({"urls": list(completadas), "fecha": datetime.now().isoformat()})
    )

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Scraper de información migratoria v2")
    parser.add_argument("--pais",            type=str, help="Código ISO del país (AR, ES, UY)")
    parser.add_argument("--limit",           type=int, help="Procesar solo las primeras N URLs")
    parser.add_argument("--resume",          action="store_true")
    parser.add_argument("--dry-run",         action="store_true", help="No guardar nada")
    parser.add_argument("--export-firestore", action="store_true", help="Generar JSON para Firestore")
    args = parser.parse_args()

    # Seleccionar países a procesar
    paises_a_procesar = {}
    if args.pais:
        codigo = args.pais.upper()
        if codigo not in PAISES:
            log(f"País no reconocido: {codigo}. Opciones: {list(PAISES.keys())}", "ERROR")
            sys.exit(1)
        paises_a_procesar[codigo] = PAISES[codigo]
    else:
        paises_a_procesar = PAISES

    # Construir lista de (url, pais_iso, config)
    todas_las_urls = []
    for pais_iso, config in paises_a_procesar.items():
        urls = config["urls"][:args.limit] if args.limit else config["urls"]
        for url in urls:
            todas_las_urls.append((url, pais_iso, config))

    completadas = cargar_progreso() if args.resume else set()
    pendientes  = [(u, p, c) for u, p, c in todas_las_urls if u not in completadas]

    if not pendientes:
        log("✅ Todo ya procesado. Usá sin --resume para re-ejecutar.")
        return

    # Cargar resultados previos si hay
    resultados = []
    if args.resume and Path(OUTPUT_FILE).exists():
        resultados = json.loads(Path(OUTPUT_FILE).read_text(encoding="utf-8"))

    log(f"🚀 {len(pendientes)} URLs a procesar en {len(paises_a_procesar)} país/es")
    log(f"   Países: {', '.join(paises_a_procesar.keys())}")

    for i, (url, pais_iso, config) in enumerate(pendientes, 1):
        log(f"[{i}/{len(pendientes)}] [{pais_iso}] {url}")

        registro = {
            "url":        url,
            "pais_iso":   pais_iso,
            "scraped_at": datetime.now(timezone.utc).isoformat(),
            "error":      None,
            "data":       None,
        }

        try:
            html = descargar(url)
            data = parsear(html, url, pais_iso, config)
            registro["data"] = data

            cat       = data.get("categoria", "?")
            titulo    = (data.get("titulo") or "Sin título")[:60]
            objetivos = ", ".join(data.get("objetivos") or [])
            n_req     = len(data.get("requisitos") or data.get("documentacion_exigible") or [])
            ue_only   = "🇪🇺 solo UE" if data.get("solo_pasaporte_ue") else ""
            log(f"  ✅ [{cat}] [{objetivos}] {titulo} — {n_req} req {ue_only}")

        except Exception as e:
            registro["error"] = str(e)
            log(f"  ❌ Error: {e}", "ERROR")

        resultados.append(registro)
        completadas.add(url)

        if not args.dry_run:
            Path(OUTPUT_FILE).write_text(
                json.dumps(resultados, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            guardar_progreso(completadas)

        if i < len(pendientes):
            time.sleep(PAUSA_SEGUNDOS)

    # Resumen
    ok      = sum(1 for r in resultados if r.get("data") and r["data"].get("status") == "ok")
    errores = len(resultados) - ok
    log(f"\n{'─'*56}")
    log(f"✅ Exitosos : {ok}   ❌ Errores: {errores}")
    log(f"📁 Guardado : {OUTPUT_FILE}")

    if args.export_firestore:
        docs = exportar_firestore(resultados)
        Path(FIRESTORE_FILE).write_text(
            json.dumps(docs, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        log(f"🔥 Firestore: {FIRESTORE_FILE} ({len(docs)} documentos)")

        # También generar resumen por país y categoría
        resumen = {}
        for d in docs:
            pais = d["paisIso"]
            cat  = d["categoria"]
            resumen.setdefault(pais, {}).setdefault(cat, 0)
            resumen[pais][cat] += 1
        log("\n  Documentos por país y categoría:")
        for pais, cats in resumen.items():
            log(f"  {pais}: {dict(cats)}")

    if errores:
        log("\n  URLs con error:")
        for r in resultados:
            if r.get("error"):
                log(f"    [{r['pais_iso']}] {r['url']}")


if __name__ == "__main__":
    main()