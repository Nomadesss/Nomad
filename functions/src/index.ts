import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import fetch from "node-fetch";

admin.initializeApp();
const db = admin.firestore();

// ── Tipos ─────────────────────────────────────────────────────

interface LocationData {
  gps: {
    lat?: number;
    lng?: number;
    accuracy?: number;
    city?: string;
    country?: string;
    countryCode?: string;
    granted: boolean;
  };
  ip: {
    address?: string;
    country?: string;
    countryCode?: string;
    city?: string;
    org?: string;
    resolved: boolean;
  };
  timezone: {
    name?: string;
    offsetMinutes: number;
  };
}

interface IPApiResponse {
  status: string;
  country?: string;
  countryCode?: string;
  city?: string;
  org?: string;
  query?: string;
  proxy?: boolean;
  hosting?: boolean;
}

// ── Cloud Function principal ──────────────────────────────────

export const validateTrustScore = functions.https.onCall(
  async (data, context) => {

    // Verificar autenticación
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "El usuario debe estar autenticado."
      );
    }

    const uid         = context.auth.uid;
    const clientScore = data.clientScore as number ?? 0;
    const locationData = data.locationData as LocationData;

    let serverScore = clientScore;
    const bonuses:   string[] = [];
    const penalties: string[] = [];
    const signals:   string[] = [];

    try {

      // ── 1. Verificar IP desde el servidor ─────────────────
      // La IP real del cliente — más confiable que la del dispositivo
      const clientIP = context.rawRequest?.ip ??
                       context.rawRequest?.headers?.["x-forwarded-for"]
                         ?.toString().split(",")[0].trim();

      let serverIPCountry: string | undefined;
      let isVPN = false;

      if (clientIP) {
        try {
          // ip-api.com con campos de proxy/VPN (plan pro requerido para proxy)
          const ipRes = await fetch(
            `http://ip-api.com/json/${clientIP}?fields=status,country,countryCode,city,org,proxy,hosting`
          );
          const ipData = await ipRes.json() as IPApiResponse;

          if (ipData.status === "success") {
            serverIPCountry = ipData.countryCode;

            // Penalizar si es VPN o hosting (señal sospechosa)
            if (ipData.proxy || ipData.hosting) {
              isVPN = true;
              serverScore = Math.max(0, serverScore - 20);
              penalties.push("IP identificada como VPN o hosting");
            } else {
              signals.push("IP verificada server-side");
            }

            // Comparar IP del servidor con IP reportada por el cliente
            if (locationData?.ip?.address &&
                locationData.ip.address !== clientIP) {
              serverScore = Math.max(0, serverScore - 10);
              penalties.push("IP del cliente no coincide con IP del servidor");
            } else {
              bonuses.push("IP del cliente coincide con servidor");
              serverScore = Math.min(100, serverScore + 5);
            }
          }
        } catch (_) {
          // Fallo silencioso — no penalizar por error de red
        }
      }

      // ── 2. Consistencia GPS vs IP server-side ─────────────
      if (serverIPCountry && locationData?.gps?.countryCode) {
        const gpsCountry = locationData.gps.countryCode.toLowerCase();
        const ipCountry  = serverIPCountry.toLowerCase();

        if (gpsCountry === ipCountry) {
          bonuses.push("GPS y IP server-side coinciden en país");
          serverScore = Math.min(100, serverScore + 5);
        } else if (!isVPN) {
          penalties.push(`GPS (${gpsCountry}) no coincide con IP server (${ipCountry})`);
          serverScore = Math.max(0, serverScore - 10);
        }
      }

      // ── 3. Verificar usuario en Firebase Auth ─────────────
      const userRecord = await admin.auth().getUser(uid);

      // Bonus por email verificado (doble check server-side)
      if (userRecord.emailVerified) {
        signals.push("Email verificado confirmado server-side");
      }

      // Bonus por teléfono verificado
      if (userRecord.phoneNumber) {
        bonuses.push("Teléfono verificado confirmado server-side");
        serverScore = Math.min(100, serverScore + 5);
      }

      // Penalizar cuentas muy nuevas (< 1 hora)
      const creationTime = new Date(
        userRecord.metadata.creationTime ?? ""
      ).getTime();
      const ageMinutes   = (Date.now() - creationTime) / 1000 / 60;

      if (ageMinutes < 60) {
        signals.push("Cuenta nueva (< 1 hora)");
        // No penalizamos — es normal en registro
      }

      // ── 4. Determinar nivel ───────────────────────────────
      const finalScore = Math.min(100, Math.max(0, serverScore));
      let level: string;
      if (finalScore >= 70)      level = "alto";
      else if (finalScore >= 40) level = "medio";
      else                       level = "bajo";

      // ── 5. Guardar score validado en Firestore ────────────
      await db.collection("users").doc(uid).set({
        trustScore: {
          score:                finalScore,
          level,
          clientScore,
          serverScore:          finalScore,
          bonuses,
          penalties,
          signals,
          isVPN,
          pendingCloudValidation: false,
          validatedAt:          admin.firestore.FieldValue.serverTimestamp(),
          source:               "cloud",
        },
      }, { merge: true });

      return { score: finalScore, level, bonuses, penalties };

    } catch (error) {
      console.error("Error en validateTrustScore:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Error al validar el score de confianza."
      );
    }
  }
);

// ── Recalcular score cuando cambia el teléfono ────────────────

export const onUserPhoneVerified = functions.firestore
  .document("users/{uid}")
  .onUpdate(async (change, context) => {

    const before = change.before.data();
    const after  = change.after.data();
    const uid    = context.params.uid;

    // Solo actuar si el teléfono cambió
    if (before?.phone === after?.phone) return null;

    try {
      const userRecord = await admin.auth().getUser(uid);
      if (!userRecord.phoneNumber) return null;

      // Sumar puntos por teléfono verificado al score existente
      const currentScore = after?.trustScore?.score ?? 0;
      const newScore = Math.min(100, currentScore + 20);

      await db.collection("users").doc(uid).set({
        trustScore: {
          score:      newScore,
          level:      newScore >= 70 ? "alto" : newScore >= 40 ? "medio" : "bajo",
          updatedAt:  admin.firestore.FieldValue.serverTimestamp(),
        },
      }, { merge: true });

    } catch (_) {}

    return null;
  });