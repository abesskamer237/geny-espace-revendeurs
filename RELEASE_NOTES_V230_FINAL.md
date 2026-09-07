# v2.3.0 FINAL COMPATIBLE — Release Notes

Cette archive reprend le serveur v2.3.0 PRO fourni et corrige uniquement les points de packaging/déploiement détectés lors de l'audit de compatibilité.

- API `/api/` conservée.
- Réseau Docker externe auto-créé par l'installateur.
- Secrets PostgreSQL/JWT générés automatiquement si absents ou placeholders.
- Nginx compatible avec `ENSPY_DOMAIN`.
- Certificat TLS aligné sur le domaine configuré.
- Renouvellement TLS sans nom de conteneur codé en dur.
- Diagnostic TLS aligné sur le domaine.
- Documentation du mot de passe administrateur corrigée.
- Audit Android ↔ serveur ajouté.

Aucune route API métier n'a été supprimée ou renommée dans cette correction.
