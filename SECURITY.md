# Sécurité : ce qui est en place, et comment le défendre

## Authentification et sessions
- Mots de passe : PBKDF2-SHA256, sel aléatoire, 100 000 itérations. Jamais stockés ni renvoyés en clair.
- Jeton de session JWT (HS256, 7 jours) avec un numéro de version `tv`. Changer son mot de passe, le réinitialiser, ou « Déconnecter tous mes appareils » incrémente ce numéro : tous les anciens jetons sont refusés immédiatement. Un compte supprimé est refusé aussi.
- 2FA TOTP (RFC 6238, testé sur le vecteur de test officiel), obligatoire pour médecins et admin avec `REQUIRE_2FA=1`.
- **Limitation de débit (table `login_attempts`)** : connexion 5 échecs par email et 20 par IP sur 15 min (puis 429, même avec le bon mot de passe) ; création de compte 10 par IP et par heure ; « mot de passe oublié » 5 par IP et par heure.
- Mot de passe oublié : jeton aléatoire de 256 bits, stocké haché (SHA-256), valable 1 h, usage unique. Réponse identique que l'email existe ou non (pas d'énumération de comptes).

## Données
- Messages et documents des patients : chiffrement applicatif AES-GCM (clé `DATA_KEY`, IV aléatoire par valeur), en plus du chiffrement de la base par Neon.
- Accès aux dossiers et documents réservé aux médecins liés par un rendez-vous non annulé. Chaque lecture est inscrite dans `audit_logs`.
- Documents servis avec `Content-Type` fixe, `nosniff` et une CSP `sandbox` ; types acceptés : JPG, PNG, WebP, PDF (pas de SVG ni HTML).
- Droit d'accès et à l'effacement : export JSON et suppression/anonymisation en libre-service.
- Ordonnances : signature HMAC-SHA256 vérifiable publiquement par code.

## Paiements
- Le webhook n'est accepté que (a) avec le secret partagé comparé en temps constant, ou (b) après confirmation directe par l'API de l'opérateur. Le montant est vérifié. Un paiement confirmé ne peut pas être annulé par un second webhook.
- Une annulation d'un rendez-vous payé crée un remboursement à traiter par l'administration (traçabilité complète).

## Tests
`npm test` : 10 tests unitaires (JWT falsifié, TOTP RFC 6238, chiffrement, validations) + 22 tests d'intégration contre un vrai Postgres en mémoire (PGlite) : limitation de débit, double réservation, reprogrammation, paiements simulés PayGate, webhook forgé, remboursement, avis, chiffrement en base, accès aux documents, rappels, réinitialisation, révocation de sessions, export et suppression.

## Limites connues (à dire honnêtement à un jury)
- Les jetons passent aussi en paramètre d'URL pour ouvrir ordonnances et documents dans un nouvel onglet (`?t=`) : ils peuvent apparaître dans l'historique du navigateur. Amélioration possible : jeton à usage unique de courte durée.
- Jeton de session stocké dans le stockage local du navigateur (pas de cookie HttpOnly). Un XSS donnerait accès à la session ; Flutter Web n'insère pas de HTML non maîtrisé, mais c'est le compromis de l'architecture actuelle.
- La limitation de débit s'appuie sur l'adresse IP fournie par Cloudflare ; l'email, lui, est limité indépendamment.
- Le chiffrement applicatif ne couvre pas les notes de consultation ni le profil médical (allergies, antécédents) : à étendre si nécessaire.
- Intégration PayGate non testée contre le service réel (voir docs/INSTALLATION.md).
