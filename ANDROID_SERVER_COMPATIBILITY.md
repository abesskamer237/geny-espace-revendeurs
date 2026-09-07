# ENSPY Android 2.3.0 ↔ Server 2.3.0 — Compatibility Audit

## Résultat

La couche API du serveur 2.3.0 conserve les routes utilisées par l'application Android ENSPY 2.3.0.

Routes Android vérifiées lors de l'audit :
- `/api/healthz`
- `/api/readyz`
- `/api/version`
- `/api/auth/login`
- `/api/auth/register`
- `/api/documents`
- `/api/documents/recent`
- `/api/documents/upload`
- `/api/documents/files/:filename`
- `/api/contributions`
- `/api/events`
- `/api/levels`
- `/api/subjects`
- `/api/notifications`
- `/api/ads`
- `/api/forum/posts`
- `/api/forum/posts/trending`
- `/api/academic/resources`
- `/api/academic/semesters`
- `/api/academic/ues`
- `/api/academic/years`

## Points corrigés dans cette livraison

1. Le réseau Docker externe `enspy_network` est créé automatiquement par `install.sh`.
2. `POSTGRES_PASSWORD` et `JWT_SECRET` sont générés si absents ou laissés sous forme de placeholder.
3. Nginx est généré avec le domaine réellement configuré dans `ENSPY_DOMAIN`; les certificats suivent le même domaine.
4. Le renouvellement TLS n'utilise plus un nom de conteneur Nginx codé en dur.
5. `diagnose.sh` utilise le domaine configuré au lieu d'un ancien chemin `enspy-ip`.
6. La documentation ne promet plus le mot de passe admin `admin123`; le mot de passe initial est généré aléatoirement.
7. Le serveur continue à exposer l'API sous `/api/`, ce qui correspond au mécanisme d'URL de l'application Android.

## Important

Cette vérification est une **analyse statique** des contrats présents dans les deux projets. Elle ne remplace pas un test réel sur VPS avec PostgreSQL, Nginx, DNS/HTTPS et une build Android installée.
