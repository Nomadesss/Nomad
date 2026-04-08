"""
upload_to_firestore.py
======================
Sube el JSON generado por scraper_migraciones_v2.py a la colección
/migration_guides de Firestore.

Uso:
    pip install firebase-admin
    python upload_to_firestore.py                          # usa firestore_migration_data.json
    python upload_to_firestore.py --file mi_archivo.json  # otro archivo
    python upload_to_firestore.py --dry-run               # solo mostrar, no subir
    python upload_to_firestore.py --pais ES               # solo un país

Prerrequisitos:
    1. Tener descargado el archivo de credenciales de Firebase Admin SDK
       desde: Consola Firebase → Configuración del proyecto → Cuentas de servicio
       → Generar nueva clave privada
    2. Poner la ruta al archivo de credenciales en FIREBASE_CREDENTIALS_PATH
"""

import json
import argparse
import sys
from pathlib import Path
from datetime import datetime

# ── Configuración ─────────────────────────────────────────────────────────────

# Ruta al archivo de credenciales de Firebase Admin SDK
FIREBASE_CREDENTIALS_PATH = "serviceAccountKey.json"

# Archivo de entrada generado por el scraper
DEFAULT_INPUT = "firestore_migration_data.json"

# Nombre de la colección en Firestore
COLLECTION = "migration_guides"

# ─────────────────────────────────────────────────────────────────────────────

def log(msg: str):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

def init_firebase():
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        print("❌ Instalá firebase-admin: pip install firebase-admin")
        sys.exit(1)

    if not Path(FIREBASE_CREDENTIALS_PATH).exists():
        print(f"❌ No se encontró {FIREBASE_CREDENTIALS_PATH}")
        print("   Descargalo desde: Firebase Console → Configuración → Cuentas de servicio")
        sys.exit(1)

    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        firebase_admin.initialize_app(cred)

    return firestore.client()

def cargar_json(path: str) -> list:
    p = Path(path)
    if not p.exists():
        print(f"❌ No se encontró {path}")
        print("   Ejecutá primero: python scraper_migraciones_v2.py --export-firestore")
        sys.exit(1)
    with open(p, encoding="utf-8") as f:
        return json.load(f)

def subir_docs(db, docs: list, dry_run: bool = False, pais: str = None) -> dict:
    """
    Sube los documentos a Firestore usando batch writes.
    Firestore permite hasta 500 operaciones por batch.
    """
    from firebase_admin import firestore as fs

    if pais:
        docs = [d for d in docs if d.get("paisIso") == pais.upper()]
        log(f"Filtrando por país {pais.upper()}: {len(docs)} documentos")

    if not docs:
        log("⚠ No hay documentos para subir.")
        return {"subidos": 0, "errores": 0}

    stats    = {"subidos": 0, "errores": 0}
    batch    = db.batch() if not dry_run else None
    en_batch = 0
    BATCH_SIZE = 400  # margen de seguridad bajo los 500 máximos

    log(f"📦 Subiendo {len(docs)} documentos a /{COLLECTION}...")

    for i, doc in enumerate(docs, 1):
        doc_id = doc.get("id")
        if not doc_id:
            log(f"  ⚠ Documento sin ID, saltando: {doc.get('titulo', '?')[:40]}")
            stats["errores"] += 1
            continue

        if dry_run:
            log(f"  [DRY RUN] Documento: {doc_id} — {doc.get('titulo', '')[:50]}")
            stats["subidos"] += 1
            continue

        try:
            ref = db.collection(COLLECTION).document(doc_id)
            batch.set(ref, doc, merge=True)
            en_batch += 1
            stats["subidos"] += 1

            # Confirmar batch cuando llega al límite
            if en_batch >= BATCH_SIZE:
                batch.commit()
                log(f"  ✅ Batch confirmado ({en_batch} docs) — total: {stats['subidos']}")
                batch    = db.batch()
                en_batch = 0

        except Exception as e:
            log(f"  ❌ Error en {doc_id}: {e}")
            stats["errores"] += 1

    # Confirmar el último batch
    if not dry_run and en_batch > 0:
        try:
            batch.commit()
            log(f"  ✅ Último batch confirmado ({en_batch} docs)")
        except Exception as e:
            log(f"  ❌ Error en último batch: {e}")

    return stats

def imprimir_resumen(docs: list):
    """Muestra el resumen de lo que se va a subir."""
    from collections import Counter
    paises   = Counter(d.get("paisIso", "?")   for d in docs)
    cats     = Counter(d.get("categoria", "?") for d in docs)
    print(f"\n{'═'*56}")
    print(f"  DOCUMENTOS A SUBIR: {len(docs)}")
    print(f"{'─'*56}")
    print("  Por país:")
    for p, n in paises.most_common():
        print(f"    {p}: {n}")
    print("  Por categoría:")
    for c, n in cats.most_common():
        print(f"    {c:<30} {n}")
    print(f"{'═'*56}\n")

def main():
    parser = argparse.ArgumentParser(description="Subir guías migratorias a Firestore")
    parser.add_argument("--file",    default=DEFAULT_INPUT, help="Archivo JSON de entrada")
    parser.add_argument("--dry-run", action="store_true",   help="No subir, solo mostrar")
    parser.add_argument("--pais",    type=str,              help="Subir solo un país (ES, UY)")
    args = parser.parse_args()

    docs = cargar_json(args.file)
    imprimir_resumen(docs)

    if args.dry_run:
        log("🔍 Modo DRY RUN — no se escribe en Firestore")
        stats = subir_docs(None, docs, dry_run=True, pais=args.pais)
    else:
        log("🔌 Conectando con Firebase...")
        db    = init_firebase()
        stats = subir_docs(db, docs, dry_run=False, pais=args.pais)

    log(f"\n{'─'*56}")
    log(f"✅ Subidos : {stats['subidos']}")
    log(f"❌ Errores : {stats['errores']}")
    log(f"🔗 Colección: /{COLLECTION}")

if __name__ == "__main__":
    main()