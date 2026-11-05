# Guide médecin
1. **Inscription** : numéro d'ordre obligatoire. Compte actif après validation par l'administration (notification à l'activation).
2. **Disponibilités** : onglet Disponibilités (créneaux hebdomadaires). Congés : bloquer des jours.
3. **Agenda** : chaque carte montre le patient, l'heure et l'état du paiement (« Payé », « Non payé »...). Notification à chaque nouveau rendez-vous, annulation, reprogrammation, message ou avis.
4. **Reprogrammer** : bouton « Reprogrammer » : choisissez un jour et un créneau libre. Le patient est prévenu.
5. **Consultation** : « Lancer » ouvre la salle vidéo (Jitsi ou Daily). Si `REQUIRE_PAYMENT=1`, la salle exige un paiement confirmé.
6. **Dossier** : allergies, antécédents, ordonnances passées et **documents déposés par le patient** (résultats). Accès autorisé seulement si un rendez-vous non annulé vous lie au patient ; chaque consultation est enregistrée dans le journal d'audit.
7. **Notes** : notes de consultation par rendez-vous.
8. **Ordonnance** : saisir les médicaments ; l'ordonnance est signée électroniquement et vérifiable par code. Le patient est notifié.
9. **Messages** : messagerie chiffrée par rendez-vous.
10. **Avis** : les patients peuvent vous noter après une consultation terminée. La note moyenne est visible dans la liste des médecins.
11. **Mon compte** : 2FA (obligatoire si activé), mot de passe, export et suppression des données.
