# Guide administrateur
1. **Validation** : vérifier numéro d'ordre ou licence, puis Valider ou Refuser. L'utilisateur est notifié.
2. **Comptes** : rechercher un utilisateur. « Réinitialiser le mot de passe » génère un mot de passe temporaire à communiquer (option : réinitialiser aussi la 2FA). Toutes les sessions de ce compte sont fermées. L'action est tracée. Les utilisateurs peuvent aussi se dépanner seuls par email (« Mot de passe oublié ») si Resend est configuré.
3. **Litiges** : traiter les signalements, ajouter une note de résolution. Les réponses de l'assistant IA signalées par les utilisateurs arrivent ici (« Réponse de l'assistant IA signalée : ... »).
4. **Statistiques** : consultations, chiffre d'affaires brut, commission, comptes actifs.
5. **Suivi > Remboursements** : une consultation payée puis annulée passe en « Remboursement dû ». Rembourser le patient par mobile money (numéro affiché), puis « Marquer comme remboursé » : le patient est notifié.
6. **Suivi > Journal d'audit** : 100 dernières actions (connexions, accès aux dossiers et documents, ordonnances, paiements, remboursements, exports et suppressions de compte). Table `audit_logs`.
7. **Demandes RGPD** : l'utilisateur exporte et supprime lui-même ses données depuis Mon compte. Une suppression anonymise le compte ; les ordonnances et rendez-vous passés sont conservés sous forme anonymisée.
8. **Tâches planifiées** : les rappels partent via GitHub Actions (voir docs/INSTALLATION.md, section 7). Vérifier que le workflow `rappels-rendez-vous` est actif.
