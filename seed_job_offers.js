/**
 * seed_job_offers.js
 * Crea la colección job_offers en Firestore con datos de ejemplo.
 *
 * Uso: node seed_job_offers.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ─── Datos de ejemplo ───────────────────────────────────────────────────────

const EMPLOYER_ID = '6sPAdp8rnXYlHZokr1YKEhAl64y1';

const jobOffers = [
  {
    employerId:   EMPLOYER_ID,
    employerName: 'TechLatam S.A.',
    title:        'Desarrollador Flutter Senior',
    company:      'TechLatam S.A.',
    location:     'Buenos Aires, Argentina',
    salary:       'USD 3.500–5.000/mes',
    description:  'Buscamos un desarrollador Flutter con 3+ años de experiencia para trabajar en nuestra app de fintech. Conocimiento en Firebase, BLoC y clean architecture. Excelente cultura de trabajo remoto y beneficios.',
    modality:     'Remoto',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'Nomad Partners',
    title:        'Diseñadora UX/UI',
    company:      'Nomad Partners',
    location:     'Madrid, España',
    salary:       'EUR 2.800–3.800/mes',
    description:  'Empresa especializada en experiencias digitales para migrantes busca diseñadora UX/UI con dominio de Figma y experiencia en apps móviles. Idealmente con experiencia propia como migrante o trabajando con comunidades latinoamericanas.',
    modality:     'Híbrido',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'GlobalOps Canadá',
    title:        'Analista de Datos',
    company:      'GlobalOps Canadá',
    location:     'Toronto, Canadá',
    salary:       'CAD 65.000–80.000/año',
    description:  'Empresa de logística con operaciones en Latinoamérica busca analista de datos con experiencia en SQL, Python y Power BI. Patrocinamos visa de trabajo. Excelentes beneficios y plan de carrera.',
    modality:     'Presencial',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'LegalMigrante',
    title:        'Abogado/a Especialista en Inmigración',
    company:      'LegalMigrante',
    location:     'Lisboa, Portugal',
    salary:       'EUR 2.200–3.000/mes',
    description:  'Estudio jurídico líder en asesoría migratoria busca abogado con experiencia en derecho de extranjería portugués o español. Inglés y español fluidos. Posibilidad de trabajo remoto parcial.',
    modality:     'Híbrido',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 4 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'RemoteFirst GmbH',
    title:        'Backend Engineer (Node.js)',
    company:      'RemoteFirst GmbH',
    location:     'Berlín, Alemania',
    salary:       'EUR 55.000–75.000/año',
    description:  'Startup de HR tech busca backend engineer con experiencia en Node.js, TypeScript y bases de datos relacionales. Equipo 100% remoto y distribuido. No se requiere visa alemana — podés trabajar desde cualquier país.',
    modality:     'Remoto',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'Cocina Latina BCN',
    title:        'Chef de Cocina Latinoamericana',
    company:      'Cocina Latina BCN',
    location:     'Barcelona, España',
    salary:       'EUR 1.800–2.400/mes',
    description:  'Restaurante especializado en gastronomía latinoamericana busca chef con experiencia en cocina peruana, mexicana o argentina. Contrato de trabajo con posibilidad de patrocinio de visa. Turno partido.',
    modality:     'Presencial',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 6 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'SaludPlus Melbourne',
    title:        'Enfermero/a Profesional',
    company:      'SaludPlus Melbourne',
    location:     'Melbourne, Australia',
    salary:       'AUD 75.000–95.000/año',
    description:  'Red de clínicas privadas en Melbourne busca enfermeros con título universitario. Patrocinamos visa Skilled Worker. Reconocimiento de títulos latinoamericanos facilitado. Alojamiento temporal incluido.',
    modality:     'Presencial',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'EduLatam Online',
    title:        'Profesor/a de Español (online)',
    company:      'EduLatam Online',
    location:     'Remoto (cualquier país)',
    salary:       'USD 18–28/hora',
    description:  'Plataforma de enseñanza de idiomas busca profesores nativos de español. Horario flexible, trabajás desde donde quieras. Mínimo 10 horas semanales. Ideal para migrantes que buscan ingresos mientras se establecen.',
    modality:     'Remoto',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 8 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'FinTech Ámsterdam',
    title:        'Product Manager',
    company:      'FinTech Ámsterdam',
    location:     'Ámsterdam, Países Bajos',
    salary:       'EUR 70.000–90.000/año',
    description:  'Scale-up de pagos internacionales busca PM con 4+ años de experiencia en productos digitales. Inglés fluido requerido. Beneficio: 30% Ruling fiscal para candidatos que vengan del exterior. Relocalización asistida.',
    modality:     'Híbrido',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 9 * 24 * 60 * 60 * 1000)),
  },
  {
    employerId:   EMPLOYER_ID,
    employerName: 'Construcciones Andina',
    title:        'Ingeniero Civil / Obras',
    company:      'Construcciones Andina',
    location:     'Santiago, Chile',
    salary:       'CLP 2.800.000–4.000.000/mes',
    description:  'Empresa constructora en expansión busca ingeniero civil para liderar obras residenciales. 3+ años de experiencia. Trámite de visa chilena patrocinado para candidatos internacionales.',
    modality:     'Presencial',
    active:       true,
    createdAt:    admin.firestore.Timestamp.fromDate(new Date(Date.now() - 10 * 24 * 60 * 60 * 1000)),
  },
];

// ─── Seed ───────────────────────────────────────────────────────────────────

async function seed() {
  // Borrar las ofertas del employer anterior (seed_employer_demo)
  const old = await db.collection('job_offers')
    .where('employerId', '==', 'seed_employer_demo')
    .get();

  if (!old.empty) {
    const delBatch = db.batch();
    old.docs.forEach((d) => delBatch.delete(d.ref));
    await delBatch.commit();
    console.log(`\n🗑️  Borradas ${old.size} ofertas del employer anterior.\n`);
  }

  console.log(`🌱 Creando ${jobOffers.length} ofertas para uid="${EMPLOYER_ID}"...\n`);

  const batch = db.batch();
  for (const offer of jobOffers) {
    const ref = db.collection('job_offers').doc();
    batch.set(ref, offer);
    console.log(`  ✓ ${offer.title} — ${offer.company} (${offer.location})`);
  }
  await batch.commit();

  console.log(`\n✅ Listo. ${jobOffers.length} ofertas creadas para tu usuario.\n`);
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Error en seed:', err);
  process.exit(1);
});
