# Référence rapide de l'API (`/api`)
Authentification : `Authorization: Bearer JETON` (ou `?t=JETON` pour les pages ouvertes dans un onglet). Erreurs : `{ "error": "message" }`.

## Compte
| Méthode et route | Rôle |
|---|---|
| POST /auth/register, /auth/login | Inscription, connexion (limitées : 429) |
| POST /auth/forgot, /auth/reset | Mot de passe oublié (email), nouveau mot de passe avec jeton |
| POST /auth/logout-all | Ferme toutes les sessions |
| POST /me/password | Change le mot de passe, renvoie un nouveau jeton |
| GET /me/export, POST /me/delete | Export JSON, suppression/anonymisation |
| GET /me/notifications, POST /me/notifications/read, GET /me/unread | Notifications et compteurs |

## Rendez-vous
| Route | Rôle |
|---|---|
| POST /appointments | Réserver (montant figé) |
| POST /appointments/:id/reschedule | Reprogrammer `{starts_at}` (patient : 2 h avant, 2 fois max) |
| POST /appointments/:id/pay | Payer la consultation `{phone, provider}` |
| POST /appointments/:id/status | Annuler / terminer (annulation payée => `refund_due`) |
| POST /appointments/:id/review | Noter `{rating 1-5, comment}` (consultation terminée) |
| GET /doctors/:id/reviews | Avis d'un médecin |

## Documents
| Route | Rôle |
|---|---|
| POST /me/documents | `{name, file: "data:image/png;base64,..."}` (1 Mo, 30 max) |
| GET /me/documents, POST /me/documents/:id/delete | Liste, suppression |
| GET /documents/:id | Contenu (propriétaire ou médecin lié) |
| GET /doctor/patients/:id/documents | Liste pour le médecin lié |

## Paiement et administration
| Route | Rôle |
|---|---|
| POST /payments/webhook | `x-webhook-secret` ou confirmation PayGate ; montant vérifié |
| GET /admin/refunds, POST /admin/refunds/:id/done | Remboursements |
| GET /admin/audit | Journal d'audit |
| POST /cron/reminders | En-tête `x-cron-secret` ; rappels 24 h |

## Ajouts v2.1
| Route | Rôle |
|---|---|
| POST /chat avec `"stream": true` | Flux SSE : `data: {"conversation_id"}`, puis `{"t":"fragment"}` répétés, puis `{"done":true}` ou `{"error":"..."}`. Sans `stream` : JSON `{conversation_id, reply}` comme avant |
| GET /prescriptions/:id/data | Données complètes (médecin, patient, signature, lien de vérification) pour générer le PDF dans l'application |
