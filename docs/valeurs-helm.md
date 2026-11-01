# Valeurs du chart Helm

Fichier : `helm/guestbook/values.yaml` (défauts) et `values-<ENV>.yaml` (surcharges).
Les probes et les commandes de démarrage sont définies dans les templates, pas dans les valeurs.

## Valeurs communes

| Clé | Rôle | Défaut | dev | staging | prod |
|---|---|---|---|---|---|
| `nameOverride` | remplace le nom du chart dans les noms d'objets | `""` | — | — | — |
| `fullnameOverride` | remplace `<release>-<chart>` comme préfixe | `""` | — | — | — |
| `commonLabels.environment` | label `environment` sur tous les objets | `dev` | `dev` | `staging` | `prod` |
| `commonLabels.team` | label `team` sur tous les objets | `plateforme` | `plateforme` | `plateforme` | `plateforme` |

## Frontend

| Clé | Rôle | Défaut | dev | staging | prod |
|---|---|---|---|---|---|
| `frontend.replicaCount` | nombre de pods | `2` | `2` | `2` | `3` |
| `frontend.image.repository` | dépôt de l'image | `gcr.io/google-samples/gb-frontend` | — | — | — |
| `frontend.image.tag` | tag (jamais `latest`) | `v5` | — | — | — |
| `frontend.image.pullPolicy` | politique de pull | `IfNotPresent` | — | — | — |
| `frontend.service.name` | nom du Service (DNS) | `frontend` | — | — | — |
| `frontend.service.type` | `ClusterIP` ou `LoadBalancer` | `LoadBalancer` | `LoadBalancer` | `LoadBalancer` | `LoadBalancer` |
| `frontend.service.port` | port du Service | `80` | `8080` | `8081` | `8082` |
| `frontend.service.targetPort` | port du conteneur | `80` | `80` | `80` | `80` |
| `frontend.env.GET_HOSTS_FROM` | mode de résolution des hôtes Redis | `dns` | `dns` | `dns` | `dns` |
| `frontend.resources.requests.cpu` | CPU demandé | `100m` | `100m` | `200m` | `250m` |
| `frontend.resources.requests.memory` | mémoire demandée | `128Mi` | `128Mi` | `256Mi` | `256Mi` |
| `frontend.resources.limits.cpu` | CPU maximal | `250m` | `250m` | `500m` | `500m` |
| `frontend.resources.limits.memory` | mémoire maximale | `256Mi` | `256Mi` | `512Mi` | `512Mi` |

En phase de test sur GKE, `frontend.service.type` est passé en `ClusterIP` avec
`--set frontend.service.type=ClusterIP`, sans modifier les fichiers.

## Redis leader

| Clé | Rôle | Défaut | dev | staging | prod |
|---|---|---|---|---|---|
| `redisLeader.replicaCount` | nombre de pods (doit rester 1) | `1` | `1` | `1` | `1` |
| `redisLeader.image.repository` | dépôt de l'image | `redis` | — | — | — |
| `redisLeader.image.tag` | tag | `7-alpine` | — | — | — |
| `redisLeader.image.pullPolicy` | politique de pull | `IfNotPresent` | — | — | — |
| `redisLeader.service.name` | nom du Service (DNS) | `redis-leader` | — | — | — |
| `redisLeader.service.port` | port du Service | `6379` | — | — | — |
| `redisLeader.service.targetPort` | port du conteneur | `6379` | — | — | — |
| `redisLeader.persistence.enabled` | active le PVC | `true` | `true` | `true` | `true` |
| `redisLeader.persistence.size` | taille du volume | `1Gi` | `1Gi` | `2Gi` | `5Gi` |
| `redisLeader.persistence.accessMode` | mode d'accès | `ReadWriteOnce` | — | — | — |
| `redisLeader.persistence.storageClass` | classe de stockage (`""` = défaut du cluster) | `""` | — | — | — |
| `redisLeader.resources.requests.cpu` | CPU demandé | `100m` | — | — | — |
| `redisLeader.resources.requests.memory` | mémoire demandée | `128Mi` | — | — | — |
| `redisLeader.resources.limits.cpu` | CPU maximal | `250m` | — | — | — |
| `redisLeader.resources.limits.memory` | mémoire maximale | `256Mi` | — | — | — |

## Redis follower

| Clé | Rôle | Défaut | dev | staging | prod |
|---|---|---|---|---|---|
| `redisFollower.replicaCount` | nombre de pods | `1` | `1` | `2` | `2` |
| `redisFollower.image.repository` | dépôt de l'image | `redis` | — | — | — |
| `redisFollower.image.tag` | tag | `7-alpine` | — | — | — |
| `redisFollower.image.pullPolicy` | politique de pull | `IfNotPresent` | — | — | — |
| `redisFollower.service.name` | nom du Service (DNS) | `redis-follower` | — | — | — |
| `redisFollower.service.port` | port du Service | `6379` | — | — | — |
| `redisFollower.service.targetPort` | port du conteneur | `6379` | — | — | — |
| `redisFollower.resources.requests.cpu` | CPU demandé | `100m` | — | — | — |
| `redisFollower.resources.requests.memory` | mémoire demandée | `128Mi` | — | — | — |
| `redisFollower.resources.limits.cpu` | CPU maximal | `250m` | — | — | — |
| `redisFollower.resources.limits.memory` | mémoire maximale | `256Mi` | — | — | — |

## Probes (dans les templates)

| Composant | Readiness | Liveness |
|---|---|---|
| `frontend` | `httpGet /` sur `http`, `initialDelaySeconds: 10`, `periodSeconds: 5` | `httpGet /` sur `http`, `initialDelaySeconds: 20`, `periodSeconds: 10` |
| `redis-leader` | `exec redis-cli ping`, `initialDelaySeconds: 5`, `periodSeconds: 5` | `exec redis-cli ping`, `initialDelaySeconds: 15`, `periodSeconds: 10` |
| `redis-follower` | `exec redis-cli ping`, `initialDelaySeconds: 5`, `periodSeconds: 5` | `exec redis-cli ping`, `initialDelaySeconds: 15`, `periodSeconds: 10` |

Justification : la readiness du frontend vérifie que la page est réellement servie (Apache + PHP),
pas seulement que le port est ouvert ; la liveness utilise les mêmes seuils mais avec des délais
plus longs pour éviter les redémarrages en cascade pendant un pic de charge. Pour Redis, `ping`
vérifie que le processus répond à une commande, ce qu'un simple test TCP ne garantit pas.

## Choix des ressources

Les valeurs suivent la charge attendue de chaque environnement :

- `dev` : un seul utilisateur, aucune contrainte — requêtes minimales (100m / 128Mi), limites à
  2,5 fois pour absorber les pics de démarrage sans étranglement.
- `staging` : dimensionné comme une préproduction, mémoire doublée (256Mi → 512Mi de limite) pour
  valider un comportement proche de la production.
- `prod` : trois frontends et deux followers ; requêtes plus hautes pour que la capacité soit
  réservée et non dépendante du hasard de la planification.

Les limites restent à 2 à 5 fois les requêtes : assez pour les pics, assez basses pour que
l'orchestrateur puisse planifier plusieurs réplicas sur un même nœud. Sur GKE Autopilot, les
requêtes inférieures aux minimums d'Autopilot sont arrondies à la hausse.
