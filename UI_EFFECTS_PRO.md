# ENSPY Server Admin UI — Effets Pro

Le serveur peut conserver son bundle web actuel. Pour éviter de casser le JavaScript minifié,
aucune transformation automatique de ce bundle n'est faite ici.

La base de production doit privilégier :
- transitions courtes des cartes et boutons ;
- hover/focus accessibles ;
- feedback de chargement ;
- skeleton/spinner pour les opérations réseau ;
- transitions de modal ;
- feedback visuel succès/erreur ;
- respect de `prefers-reduced-motion`.

Ces effets doivent être intégrés dans le bundle source de l'interface lorsqu'il est disponible,
plutôt que par recherche/remplacement aveugle dans un fichier minifié.
