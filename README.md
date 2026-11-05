# DoktaNet - MVP Phase 1

Flutter Web + Cloudflare Pages Functions (API) + Neon (PostgreSQL) + Cloudflare R2.

## Mise en route
1. Neon : `npm install`, `neon login`, `neon deploy`, `neon env pull` (écrit `.env.local`), puis `npm run db:setup` (schéma + données de test, comptes `*.doktanet.test`, mot de passe `Test1234!`). Sans données de test : `npm run db:schema`. Base déjà créée : `migration_chat.sql` puis `migration_final.sql`.
2. R2 : optionnel (voir docs/INSTALLATION.md). Sans bloc `[[r2_buckets]]` dans `wrangler.toml`, tout fonctionne.
3. Pages : créer le projet `doktanet`. Variables (secrets) : `DATABASE_URL`, `JWT_SECRET`, `DATA_KEY`, `CRON_SECRET`, `RESEND_API_KEY`, `MAIL_FROM`, `PAYGATE_TOKEN`, `REQUIRE_PAYMENT`, `COMMISSION_PCT`, `PAY_SANDBOX` (`1` en test), `PAY_WEBHOOK_SECRET`, `DAILY_API_KEY` (optionnel), `REQUIRE_2FA` (`1` = 2FA obligatoire médecins/admin), `GROQ_API_KEY`, `GROQ_MODEL` (défaut `openai/gpt-oss-20b`). Lier le bucket R2 au binding `RX_BUCKET`.
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

## Limites connues
- Paiement : mode sandbox par défaut. Pour le réel, PayGate Global est branché (`PAYGATE_TOKEN`, `PAY_SANDBOX=0`, webhook vérifié auprès de l'opérateur) mais **non testé contre le service réel** : voir docs/INSTALLATION.md section 8.
- Vidéo : Jitsi (sans clé) ou Daily.co (si `DAILY_API_KEY`), ouverte dans un nouvel onglet.
- Hors-ligne : lecture seulement. Les actions (réserver, payer, écrire) demandent une connexion ; elles échouent avec un message clair, rien n'est mis en file d'attente.
- Notifications : dans l'application et par email. Pas de notification push native du navigateur.
- La carte utilise les tuiles publiques d'OpenStreetMap (usage modéré) : pour un fort trafic, prendre un fournisseur de tuiles dédié.
- Le code Flutter de cette version n'a pas pu être compilé dans l'environnement de rédaction (syntaxe vérifiée, API testée par 45 tests) : lancer `flutter build web` et corriger d'éventuelles erreurs de typage avant de déployer.

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

## Version 2 (sécurité, paiements, RGPD)
- **Sécurité** : limitation des tentatives de connexion, sessions révocables, mot de passe oublié par email, webhook de paiement authentifié, chiffrement AES-GCM des messages et documents. Détail et limites : `SECURITY.md`.
- **Rendez-vous** : paiement de la consultation (T-Money/Flooz), reprogrammation, remboursement à l'annulation, avis et notes des médecins, rappels 24 h avant.
- **Documents** : le patient dépose ses résultats, ses médecins les consultent (journalisé).
- **Notifications** : cloche dans la barre du haut, emails via Resend.
- **RGPD** : export JSON, suppression/anonymisation de compte, pages `web/privacy.html` et `web/terms.html`, consentement versionné.
- **Admin** : onglet Suivi (remboursements, journal d'audit).
- **Assistant IA** : réponses rendues en Markdown (gras, listes, tableaux), bouton « Signaler ».
- **Assistant IA en streaming** : la réponse s'affiche au fil de l'eau (flux SSE). Repli automatique sur la réponse complète si le flux est impossible.
- **Hors-ligne** : service worker (application chargée sans réseau après une première visite) et dernières données mémorisées pour les écrans de lecture (rendez-vous, ordonnances, commandes, rappels, médecins, pharmacies). Bannière « Connexion perdue ». Données mémorisées effacées à la déconnexion.
- **PDF natif** : ordonnance générée dans l'application (bouton « Télécharger le PDF »), sans page d'impression.
- **Carte intégrée** : OpenStreetMap dans les pharmacies (vue carte globale et fenêtre par pharmacie).
- **Dépôt de PDF** : photos ou PDF/images depuis les fichiers (1 Mo, en-tête vérifié côté serveur).
- **Tests** : `npm test` (13 unitaires, 27 d'intégration sur Postgres en mémoire, 5 sur le service worker), exécutés avant chaque déploiement.
- Migration : automatique au premier appel, ou `npm run db:migrate` (`migration_v2.sql`).

## Photos et installation (PWA)
- Photos : `assets/photos/` (4 images en 2 tailles, ~40 à 110 Ko chacune). Widgets dans `lib/photos.dart` : diaporama de la page de connexion, en-têtes d'accueil (patient, médecin, pharmacien), bandeaux des sections Médecins et Pharmacies. Pour changer une photo : remplacer les fichiers `nom_l.jpg` (grand écran, 1280 px) et `nom_s.jpg` (mobile, 720 px) et ajuster le cadrage dans `Photos`.
- Installation : la fenêtre « Installer DoktaNet » est dans `web/index.html` (Chrome, Edge, Android : invite native ; iPhone/iPad : mode d'emploi Partager > Sur l'écran d'accueil). Elle s'affiche quelques secondes après le chargement, puis se rappelle au bout de 7 jours si elle est refusée. Le bouton « Installer l'application » de Mon compte la rouvre à tout moment.

## Partage (OpenGraph) et icônes
- `web/index.html` contient les balises Open Graph et Twitter (titre, description, image `web/og-image.jpg` 1200x630). Les adresses sont en dur sur `https://doktanet.pages.dev` : à remplacer par ton nom de domaine si tu en ajoutes un (`og:url`, `og:image`, `twitter:image`, `canonical`).
- Pour voir l'aperçu : coller le lien dans WhatsApp, ou utiliser les débogueurs Facebook (developers.facebook.com/tools/debug) et LinkedIn (linkedin.com/post-inspector). Ces sites gardent l'ancien aperçu en cache : utiliser « Scrape again ».
- Icônes d'installation : `web/icons/` (Icon-192/512 pour PC et Android, Icon-maskable-192/512 pour les icônes rondes d'Android, apple-touch-icon.png pour iPhone) et `web/favicon.png`. Elles se régénèrent à partir de `assets/images/logo_white.png`.
