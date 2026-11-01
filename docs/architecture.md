# Architecture détaillée

Complément au §2 du [README](../README.md). Ce document décrit ce qui tourne, où, et par quel
chemin passent les requêtes.

## 1. Deux environnements, un seul chart

| | Local | Cloud |
|---|---|---|
| Orchestrateur | minikube (driver Docker Desktop) | GKE Autopilot (régional) |
| Création | `minikube start` | Terraform (`terraform/`) |
| Déploiement | Helm | Helm (mêmes templates) |
| Namespaces | `dev`, `staging`, `prod` | `dev`, `staging`, `prod` |
| Releases | `stack-dev`, `stack-staging`, `stack-prod` | idem |
| Exposition | `LoadBalancer` + `minikube tunnel` | `ClusterIP` + `port-forward` (test) puis `LoadBalancer` |
| Ports du frontend | 8080 / 8081 / 8082 | 8080 / 8081 / 8082 |
| Stockage | StorageClass `standard` (hostPath) | StorageClass `standard-rwo` (PD) |

Un seul chart, trois fichiers de valeurs. Aucune copie du chart par environnement.

## 2. Contenu d'un namespace

```
namespace <ENV>                                   (dev | staging | prod)
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  Service frontend ───────▶ Deployment frontend (PHP/Apache, N réplicas)  │
│  (LoadBalancer :8080/8081/8082)      │ envFrom: frontend-config           │
│  ou ClusterIP                        │                                    │
│                                      ├── écritures ──▶ Service redis-leader
│                                      └── lectures  ──▶ Service redis-follower
│                                                                          │
│  Service redis-leader (ClusterIP:6379)                                   │
│        │                                                                 │
│  Deployment redis-leader (1 réplica, strategy: Recreate)                 │
│        │  ConfigMap redis-leader-config → /usr/local/etc/redis/redis.conf│
│        ▼                                                                 │
│  PVC redis-leader-pvc (RWO, classe par défaut) → monté sur /data          │
│                                                                          │
│  Service redis-follower (ClusterIP:6379)                                 │
│        │                                                                 │
│  Deployment redis-follower (N réplicas, RollingUpdate)                   │
│        └── réplication : redis-server --replicaof redis-leader 6379      │
└──────────────────────────────────────────────────────────────────────────┘
```

## 3. Cycle d'une requête

1. Le navigateur du client atteint le Service `frontend` (IP publique du load balancer, ou
   `127.0.0.1:<port>` en local via `minikube tunnel`, ou `localhost:<port>` via `port-forward`).
2. Le Service répartit vers un pod `frontend`.
3. Le PHP appelle `redis-leader:6379` pour écrire, `redis-follower:6379` pour lire. Ces noms sont
   résolus par le DNS Kubernetes du namespace (le code des images les code en dur, d'où le choix
   de noms fixes — voir [ADR 001](decisions/001-noms-services.md)).
4. Le leader écrit dans `/data` (journal AOF). Le follower se synchronise en continu sur le leader.

## 4. Où sont les données, et ce qui les protège

- Le seul état persistant de l'application est le volume du leader (`/data`).
- Le PVC est en `ReadWriteOnce` : un seul nœud peut le monter, donc un seul pod leader à la fois.
  C'est ce qui impose la stratégie `Recreate` sur le leader (voir [ADR 002](decisions/002-recreate-leader.md)).
- Redis écrit un journal append-only (`appendonly yes`, `appendfsync everysec`) et des snapshots
  RDB de sécurité. Au redémarrage, Redis rejoue le journal : les messages reviennent.
- Ni le frontend ni les followers ne stockent quoi que ce soit de durable.

## 5. Frontière Terraform / Helm

```
Terraform                          Helm
─────────                          ────
projet GCP (existant)              namespaces (créés par kubectl apply)
cluster Autopilot          ──────▶ deployments, services, ConfigMaps, PVC
compte de service des nœuds        releases stack-dev / stack-staging / stack-prod
rôles IAM
state local                        historique des révisions (dans le cluster)
```

- Terraform ne connaît pas l'application : il ne déploie aucun Deployment.
- Helm ne connaît pas GCP : il ne crée aucune ressource Cloud.
- Conséquence : `terraform destroy` détruit le cluster et tout ce qu'il contient ; `helm uninstall`
  supprime les objets de la release, PVC compris (donc les données) tant que l'annotation
  `helm.sh/resource-policy: keep` n'est pas ajoutée.

## 6. Noms et labels

- Noms d'objets fixes (`frontend`, `redis-leader`, `redis-follower`, `redis-leader-pvc`,
  `frontend-config`, `redis-leader-config`) : les Services doivent garder ces noms pour le DNS,
  les autres objets suivent par cohérence et pour que les commandes de diagnostic restent stables.
- Labels communs (chart) : `helm.sh/chart`, `app.kubernetes.io/name`, `app.kubernetes.io/instance`,
  `app.kubernetes.io/managed-by`, `environment`, `team`.
- Labels de sélecteur : `app.kubernetes.io/name` + `app.kubernetes.io/instance` +
  `app.kubernetes.io/component` (jamais de version ni de version de chart : le sélecteur d'un
  Deployment est immuable).

## 7. Ce qui diffère entre `k8s/` et `helm/`

Les manifestes bruts de `k8s/` et les templates du chart décrivent les mêmes objets, mais ne sont
pas identiques : images Redis différentes, probes/ressources absentes du leader dans `k8s/`,
réplicas différents. C'est documenté comme dette technique et expliqué dans
[ADR 006](decisions/006-k8s-et-helm.md) et au §9 du [README](../README.md).
