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
| DATA_KEY | Clé de chiffrement des messages et documents (AES-GCM). `openssl rand -base64 32`. À sauvegarder : la perdre rend les données chiffrées illisibles. Sans elle, tout est stocké en clair |
| RESEND_API_KEY, MAIL_FROM | Emails (mot de passe oublié, notifications). Sans eux : « mot de passe oublié » renvoie une erreur claire et les notifications restent dans l'application |
| PAYGATE_TOKEN | Jeton PayGate Global (T-Money, Flooz). Utilisé si `PAY_SANDBOX=0` |
| REQUIRE_PAYMENT | 1 = la salle de consultation exige un paiement confirmé |
| CRON_SECRET | Secret de la tâche de rappels (même valeur que le secret GitHub du même nom) |

## 4. Test local
```
npm install
flutter pub get
npm run dev   # synchronise .env.local, construit et lance wrangler
```
Ouvrir http://localhost:8788. Comptes de test : mot de passe `Test1234!` (patient@, dr.kofi@, pharma.lome@, admin@ + `doktanet.test`).

## 5. Migration v2 (base déjà créée)
Les tables de la v2 (avis, documents, notifications, réinitialisation, limitation des connexions) et les colonnes de paiement des rendez-vous sont créées **automatiquement** au premier appel de l'API. Pour les créer à la main (recommandé en production, connexion directe) : `npm run db:migrate`. Le fichier `migration_v2.sql` est idempotent. Une base neuve (`npm run db:setup`) les contient déjà.

## 6. Déploiement
Secrets GitHub : `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`. Un push sur `main` construit l'application et la déploie sur Cloudflare Pages.

## 6. Compte administrateur
Créer un compte patient, puis dans Neon :
`update users set role='admin', status='active' where email='VOTRE_EMAIL';`

## Mise en production
- `PAY_SANDBOX=0` et intégration du fournisseur de paiement (voir le TODO dans `POST /orders/:id/pay`).
- `REQUIRE_2FA=1`.
- Valider le cadre légal de la téléconsultation avec l'Ordre des Médecins et le Ministère de la Santé.
Un pull request exécute les tests (`npm test` : 13 tests unitaires, 27 d'intégration sur un Postgres en mémoire, 5 sur le service worker). Un push sur `main` déploie seulement si les tests passent.

## 7. Rappels de rendez-vous
Cloudflare Pages n'a pas de tâches planifiées : le workflow `.github/workflows/reminders.yml` appelle `POST /api/cron/reminders` toutes les 30 minutes. Créer les secrets GitHub `APP_URL` (ex. `https://doktanet.pages.dev`) et `CRON_SECRET`, et la même valeur `CRON_SECRET` dans les variables Pages. Chaque rendez-vous des prochaines 24 h reçoit un rappel (notification dans l'application + email si Resend est configuré), une seule fois.

## 8. Paiement réel (PayGate Global)
1. Créer un compte marchand PayGate Global, obtenir le jeton d'authentification.
2. Variables : `PAYGATE_TOKEN=...`, `PAY_SANDBOX=0`.
3. Dans PayGate, déclarer l'URL de callback : `https://VOTRE-DOMAINE/api/payments/webhook`.
4. Le webhook n'est jamais cru sur parole : l'API interroge PayGate (`/api/v2/status`) avec la référence reçue avant de marquer un paiement comme payé, et vérifie le montant.
5. **À valider avec la documentation PayGate de votre compte** : les codes de statut utilisés (0 = payé, 2 = en cours, 4 = expiré, 6 = annulé) et le format du numéro (8 chiffres sans indicatif) correspondent à l'API publique au moment de l'écriture, et n'ont pas pu être testés contre le service réel. Tester avec un petit montant avant d'ouvrir au public.
Alternative sans API : garder `PAY_WEBHOOK_SECRET` et faire appeler le webhook par votre prestataire avec l'en-tête `x-webhook-secret`.

## Mise en production : liste de contrôle
- [ ] `PAY_SANDBOX=0` + `PAYGATE_TOKEN` testé avec un petit montant
- [ ] `REQUIRE_2FA=1`, `DATA_KEY` générée et sauvegardée, `JWT_SECRET` long et aléatoire
- [ ] `RESEND_API_KEY` + `MAIL_FROM` (domaine vérifié chez Resend)
- [ ] Secrets GitHub `APP_URL`, `CRON_SECRET` + variable Pages `CRON_SECRET`
- [ ] Politique de confidentialité et conditions (`web/privacy.html`, `web/terms.html`) complétées et relues par un juriste
- [ ] Cadre légal de la téléconsultation validé (Ordre des Médecins, Ministère de la Santé)
- [ ] Sauvegardes Neon (point-in-time) vérifiées

## Build web
`flutter build web --release --pwa-strategy=none --no-web-resources-cdn` (script `npm run build:web`) :
- `--pwa-strategy=none` : le service worker Flutter est remplacé par `web/doktanet_sw.js` (mode hors-ligne). Une nouvelle version s'applique au 2e chargement.
- `--no-web-resources-cdn` : CanvasKit est servi par votre domaine (donc mis en cache pour le hors-ligne) au lieu du CDN de Google.
Premier déploiement après cette version : un ancien service worker peut rester actif quelques secondes ; un rechargement suffit.
