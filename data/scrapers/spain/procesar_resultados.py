"""
procesar_resultados.py
======================
Procesa el JSON generado por scraper_migraciones.py.
Genera reportes, filtra errores y exporta a CSV.

Uso:
    python procesar_resultados.py                  # Resumen completo
    python procesar_resultados.py --export-csv     # También exporta CSV
    python procesar_resultados.py --categoria estudios
    python procesar_resultados.py --solo-errores   # Lista URLs fallidas para re-scrapear
"""

import json
import csv
import argparse
from pathlib import Path
from collections import Counter

INPUT_FILE = "migraciones_extraidas.json"
CSV_FILE   = "migraciones_export.csv"


def cargar_datos() -> list:
    if not Path(INPUT_FILE).exists():
        print(f"❌ No se encontró {INPUT_FILE}. Ejecutá el scraper primero.")
        return []
    with open(INPUT_FILE, encoding="utf-8") as f:
        return json.load(f)


def imprimir_resumen(data: list, categoria: str = None):
    total   = len(data)
    ok      = [r for r in data if r["status"] == "ok"]
    errores = [r for r in data if r["status"] != "ok"]

    if categoria:
        ok = [r for r in ok if r.get("data", {}).get("categoria") == categoria]

    print(f"\n{'═'*60}")
    print(f"  RESUMEN — {INPUT_FILE}")
    print(f"{'═'*60}")
    print(f"  Total URLs     : {total}")
    print(f"  Exitosas       : {len(ok)}")
    print(f"  Con errores    : {len(errores)}")
    if categoria:
        print(f"  Filtro categ.  : {categoria}")
    print()

    # Distribución por categoría
    categorias = Counter(
        r["data"].get("categoria", "sin_categoria")
        for r in ok
        if r.get("data")
    )
    print("  Por categoría:")
    for cat, n in categorias.most_common():
        bar = "█" * n
        print(f"    {cat:<22} {n:>3}  {bar}")
    print()

    # Detalle
    print(f"  {'#':<4} {'Categoría':<18} {'Tipo de autorización'}")
    print(f"  {'─'*4} {'─'*18} {'─'*38}")
    for i, r in enumerate(ok, 1):
        d = r.get("data", {})
        cat  = (d.get("categoria") or "?")[:17]
        tipo = (d.get("tipo_autorizacion") or "Sin datos")[:55]
        print(f"  {i:<4} {cat:<18} {tipo}")

    if errores:
        print(f"\n  ⚠ URLs con error:")
        for r in errores:
            print(f"    [{r['status']}] {r['url']}")

    print(f"\n{'═'*60}\n")


def exportar_csv(data: list):
    ok = [r for r in data if r["status"] == "ok" and r.get("data")]
    campos = [
        "url", "pais_iso", "categoria", "tipo_autorizacion",
        "descripcion_breve", "duracion", "renovable",
        "donde_solicitarlo", "plazo_resolucion", "tasas",
        "requisitos", "documentacion_exigible", "procedimiento",
        "notas_importantes", "scraped_at",
    ]
    with open(CSV_FILE, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=campos, extrasaction="ignore")
        writer.writeheader()
        for r in ok:
            d = r["data"]
            row = {
                "url":                r["url"],
                "pais_iso":           r.get("pais_iso", "ES"),
                "categoria":          d.get("categoria"),
                "tipo_autorizacion":  d.get("tipo_autorizacion"),
                "descripcion_breve":  d.get("descripcion_breve"),
                "duracion":           d.get("duracion"),
                "renovable":          d.get("renovable"),
                "donde_solicitarlo":  d.get("donde_solicitarlo"),
                "plazo_resolucion":   d.get("plazo_resolucion"),
                "tasas":              d.get("tasas"),
                "requisitos":         " | ".join(d.get("requisitos") or []),
                "documentacion_exigible": " | ".join(d.get("documentacion_exigible") or []),
                "procedimiento":      " | ".join(d.get("procedimiento") or []),
                "notas_importantes":  " | ".join(d.get("notas_importantes") or []),
                "scraped_at":         r.get("scraped_at"),
            }
            writer.writerow(row)
    print(f"  📊 CSV exportado: {CSV_FILE} ({len(ok)} filas)")


def exportar_urls_fallidas(data: list):
    errores = [r["url"] for r in data if r["status"] != "ok"]
    if not errores:
        print("  ✅ No hay URLs con error.")
        return
    with open("urls_fallidas.txt", "w") as f:
        f.write("\n".join(errores))
    print(f"  📋 {len(errores)} URLs fallidas guardadas en urls_fallidas.txt")
    print("  Re-ejecutá con: python scraper_migraciones.py --resume")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--export-csv",    action="store_true")
    parser.add_argument("--solo-errores",  action="store_true")
    parser.add_argument("--categoria",     type=str, default=None,
                        help="estudios|trabajo|residencia|proteccion|familiar|inversion|especial|nomada_digital|retorno|documento")
    args = parser.parse_args()

    data = cargar_datos()
    if not data:
        exit(1)

    if args.solo_errores:
        exportar_urls_fallidas(data)
    else:
        imprimir_resumen(data, categoria=args.categoria)
        if args.export_csv:
            exportar_csv(data)