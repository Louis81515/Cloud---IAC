# ADR 006 — `k8s/` comme référence, `helm/` comme source de vérité

## Contexte

L'énoncé demande deux choses : des manifestes Kubernetes bruts (`k8s/`) validés sur minikube, et
un chart Helm (`helm/guestbook/`) qui en dérive. Les deux décrivent les mêmes objets.

## Décision

- `k8s/` reste la **référence lisible** : un objet par fichier, commenté, sans templating, destiné
  à comprendre l'application et à la tester rapidement sur minikube.
- `helm/guestbook/` est la **source de vérité** pour les environnements (`dev`, `staging`, `prod`,
  minikube et GKE). Aucune évolution n'est appliquée à la main sur un environnement partagé.
- Le chart est dérivé des manifestes bruts : chaque objet de `k8s/` a son template.

## Écarts connus entre les deux

| Point | `k8s/` | `helm/guestbook/` | Statut |
|---|---|---|---|
| Image frontend | `us-docker.pkg.dev/.../gb-frontend:v5` | `gcr.io/google-samples/gb-frontend:v5` | à harmoniser |
| Image leader | `redis:6.0.5` | `redis:7-alpine` | à harmoniser |
| Image follower | `gb-redis-follower:v2` (script `run.sh`) | `redis:7-alpine` + `--replicaof` explicite | à harmoniser |
| Probes et ressources du leader | absentes | présentes | manifeste brut à compléter |
| Réplicas | frontend 4, follower 2 | 2/2/3 et 1/2/2 selon l'environnement | normal : les valeurs du chart priment |

Ces écarts sont assumés et documentés comme dette technique (README §9) : ils ne cassent pas le
déploiement, mais ils rendent la comparaison entre les deux dossiers trompeuse. La correction
consiste à aligner `k8s/` sur le chart pour les images et les probes du leader, puis à faire du
chart la seule évolution.

## Alternatives écartées

- **Supprimer `k8s/`** : perd la référence lisible demandée par l'énoncé et l'étape de validation
  sur minikube.
- **Générer `k8s/` depuis le chart** (`helm template`) : donne des manifestes corrects mais
  beaucoup moins lisibles pour un lecteur qui découvre l'application.
