# DoktaNet - MVP Phase 1

Flutter Web + Cloudflare Pages Functions (API) + Neon (PostgreSQL) + Cloudflare R2.

## Mise en route
1. Neon : `npm install`, `neon login`, `neon deploy`, `neon env pull` (écrit `.env.local`), puis `npm run db:setup` (schéma + données de test, comptes `*.doktanet.test`, mot de passe `Test1234!`). Sans données de test : `npm run db:schema`. Base déjà créée : `migration_chat.sql` puis `migration_final.sql`.
2. R2 : optionnel (voir docs/INSTALLATION.md). Sans bloc `[[r2_buckets]]` dans `wrangler.toml`, tout fonctionne.
3. Pages : créer le projet `doktanet`. Variables (secrets) : `DATABASE_URL`, `JWT_SECRET`, `COMMISSION_PCT`, `PAY_SANDBOX` (`1` en test), `PAY_WEBHOOK_SECRET`, `DAILY_API_KEY` (optionnel), `REQUIRE_2FA` (`1` = 2FA obligatoire médecins/admin), `GROQ_API_KEY`, `GROQ_MODEL` (défaut `openai/gpt-oss-20b`). Lier le bucket R2 au binding `RX_BUCKET`.
4. GitHub : secrets `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`. Push sur `main` : build Flutter + déploiement automatique.
5. Admin : créer un compte patient, puis dans Neon : `update users set role='admin', status='active' where email='VOTRE_EMAIL';`

## Dev local
```
copy .dev.vars.example en .dev.vars (renseigner les valeurs)
npm install
flutter pub get
flutter build web
npx wrangler pages dev build/web
```
Ouvrir http://localhost:8788 (même origine : pas de CORS).

Si `flutter build web` se plaint de fichiers manquants : `flutter create . --platforms web --project-name doktanet` puis relancer (ne touche pas à `lib/`).

## Assistant IA (Groq)
Route `POST /api/chat` (tool calling). Base déjà créée avant le chatbot : exécuter `migration_chat.sql`.
Triage : niveau d'urgence, pistes (hypothèses), jamais de diagnostic ni de dose ; alerte automatique côté serveur sur signes graves ; limite 40 messages/heure/utilisateur.

## Rôles
- Patient : inscription immédiate.
- Médecin / Pharmacien : statut "pending" jusqu'à validation par l'admin.

## Limites connues (à traiter Phase 2)
- Paiement : mode sandbox. Brancher PayGate / KKiaPay dans `POST /orders/:id/pay` (TODO dans le code) + webhook `POST /api/payments/webhook`.
- Vidéo : Jitsi (sans clé) ou Daily.co (si `DAILY_API_KEY`), ouverte dans un nouvel onglet.
- Pas encore : notifications push des rappels, mode hors-ligne, récupération de mot de passe par email (réinitialisation par l'admin), carte intégrée (lien Google Maps), PDF natif (page imprimable "Enregistrer en PDF").
- Renderer HTML Flutter : option retirée des versions récentes ; surveiller le poids du bundle (exigence 3G).

## Interface (refonte visuelle) et langues
- Thème émeraude/or, cartes animées (apparition en cascade, survol), ECG animé, squelettes de chargement, compteurs animés, navigation latérale sur grand écran.
- Bouton **FR | EN** (barre du haut et page de connexion) : bascule toute l'application en un clic, choix mémorisé. Les textes sont dans `lib/i18n.dart` (clé = texte français) : pour ajouter une phrase, utiliser `tr("texte français")` et ajouter sa traduction dans la table `_en`.
- L'assistant IA répond dans la langue choisie (champ `lang` envoyé à `POST /api/chat`).

## Finalisation (MVP complet)
- 2FA TOTP (Google Authenticator, Authy) : Mon compte. Obligatoire pour médecins et admin si `REQUIRE_2FA=1`. 5 essais de code max par 10 minutes.
- Messagerie sécurisée patient-médecin par rendez-vous.
- Congés / blocage de jours côté médecin (les créneaux disparaissent pour les patients).
- Admin : recherche de comptes, mot de passe temporaire, litiges.
- Mon compte : changement de mot de passe, signalement d'un problème.
- Guides : dossier `docs/` (installation, patient, médecin, pharmacien, admin).

## Photos et installation (PWA)
- Photos : `assets/photos/` (4 images en 2 tailles, ~40 à 110 Ko chacune). Widgets dans `lib/photos.dart` : diaporama de la page de connexion, en-têtes d'accueil (patient, médecin, pharmacien), bandeaux des sections Médecins et Pharmacies. Pour changer une photo : remplacer les fichiers `nom_l.jpg` (grand écran, 1280 px) et `nom_s.jpg` (mobile, 720 px) et ajuster le cadrage dans `Photos`.
- Installation : la fenêtre « Installer DoktaNet » est dans `web/index.html` (Chrome, Edge, Android : invite native ; iPhone/iPad : mode d'emploi Partager > Sur l'écran d'accueil). Elle s'affiche quelques secondes après le chargement, puis se rappelle au bout de 7 jours si elle est refusée. Le bouton « Installer l'application » de Mon compte la rouvre à tout moment.

## Partage (OpenGraph) et icônes
- `web/index.html` contient les balises Open Graph et Twitter (titre, description, image `web/og-image.jpg` 1200x630). Les adresses sont en dur sur `https://doktanet.pages.dev` : à remplacer par ton nom de domaine si tu en ajoutes un (`og:url`, `og:image`, `twitter:image`, `canonical`).
- Pour voir l'aperçu : coller le lien dans WhatsApp, ou utiliser les débogueurs Facebook (developers.facebook.com/tools/debug) et LinkedIn (linkedin.com/post-inspector). Ces sites gardent l'ancien aperçu en cache : utiliser « Scrape again ».
- Icônes d'installation : `web/icons/` (Icon-192/512 pour PC et Android, Icon-maskable-192/512 pour les icônes rondes d'Android, apple-touch-icon.png pour iPhone) et `web/favicon.png`. Elles se régénèrent à partir de `assets/images/logo_white.png`.
