# Guide d'installation DoktaNet

## Prérequis
- Compte Neon (PostgreSQL), compte Cloudflare (Pages + R2), compte GitHub
- Node.js 18+, Flutter (canal stable)
- Clé Groq (assistant IA). Optionnel : clé Daily.co

## 1. Base de données (Neon)
Le projet est déjà lié (`.neon`, `neon.ts` : service Postgres seul).
1. `npm install`
2. `neon login` (ouvre le navigateur, à valider une fois).
3. `neon deploy` : provisionne les services de `neon.ts`.
4. `neon env pull` : écrit `DATABASE_URL` (pooled, pour l'API) et `DATABASE_URL_UNPOOLED` (direct, pour les migrations) dans `.env.local`.
5. Compléter `.dev.vars` (copie de `.dev.vars.example`) avec `JWT_SECRET`, `GROQ_API_KEY`, etc. `npm run env:sync` recopie `DATABASE_URL` de `.env.local` vers `.dev.vars`.
6. `npm run db:setup` (schéma + données de test). Les migrations utilisent `DATABASE_URL_UNPOOLED`.
   - Base déjà créée avant la finalisation : exécuter `migration_final.sql`.
   - Sans données de test : `npm run db:schema`.
Alternative sans CLI : coller la chaîne de connexion dans `.dev.vars` (`DATABASE_URL=`).

## 2. Stockage des ordonnances (R2) : optionnel
R2 n'est pas utilisé par défaut : les ordonnances, leur signature et leur vérification sont dans Neon. Pour activer la copie JSON dans R2 : activer R2 dans le tableau de bord Cloudflare, créer le bucket `doktanet-ordonnances`, puis ajouter à `wrangler.toml` :
```
[[r2_buckets]]
binding = "RX_BUCKET"
bucket_name = "doktanet-ordonnances"
```
Sans ce bloc, le déploiement fonctionne normalement.

## 3. Variables (Cloudflare Pages > Settings > Variables)
| Variable | Rôle |
|---|---|
| DATABASE_URL | Chaîne Neon |
| JWT_SECRET | Chaîne aléatoire longue (signe aussi les ordonnances) |
| GROQ_API_KEY, GROQ_MODEL | Assistant IA (défaut openai/gpt-oss-20b) |
| PAY_SANDBOX | 1 = paiement simulé. 0 = brancher PayGate/KKiaPay |
| PAY_WEBHOOK_SECRET | Secret du webhook de paiement |
| COMMISSION_PCT | Commission affichée dans les statistiques |
| REQUIRE_2FA | 1 = 2FA obligatoire pour médecins et admin |
| DAILY_API_KEY | Optionnel (sinon visio Jitsi) |

## 4. Test local
```
npm install
flutter pub get
npm run dev   # synchronise .env.local, construit et lance wrangler
```
Ouvrir http://localhost:8788. Comptes de test : mot de passe `Test1234!` (patient@, dr.kofi@, pharma.lome@, admin@ + `doktanet.test`).

## 5. Déploiement
Secrets GitHub : `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`. Un push sur `main` construit l'application et la déploie sur Cloudflare Pages.

## 6. Compte administrateur
Créer un compte patient, puis dans Neon :
`update users set role='admin', status='active' where email='VOTRE_EMAIL';`

## Mise en production
- `PAY_SANDBOX=0` et intégration du fournisseur de paiement (voir le TODO dans `POST /orders/:id/pay`).
- `REQUIRE_2FA=1`.
- Valider le cadre légal de la téléconsultation avec l'Ordre des Médecins et le Ministère de la Santé.
