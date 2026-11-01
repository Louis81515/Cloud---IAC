# ADR 004 — Un seul chart, surcharge par environnement et par contexte

## Contexte

Trois environnements (`dev`, `staging`, `prod`) et deux contextes d'exécution (minikube, GKE)
doivent tourner avec les mêmes objets. Seules des valeurs diffèrent : réplicas, ressources, ports,
taille de volume, type de Service.

## Décision

- Un unique chart `helm/guestbook/`, jamais dupliqué.
- Les valeurs par défaut sont dans `values.yaml` ; chaque environnement ne surcharge que ce qui
  lui est propre (`values-dev.yaml`, `values-staging.yaml`, `values-prod.yaml`). Les templates ne
  contiennent **aucune** condition sur le nom de l'environnement.
- Le type du Service frontend est une valeur (`frontend.service.type`), `LoadBalancer` par défaut.
  Pour la phase de test sur GKE, il est surchargé en ligne de commande :
  `--set frontend.service.type=ClusterIP`, puis `helm upgrade` sans cette option pour ouvrir.
- Les ports diffèrent par environnement (8080/8081/8082) parce que `minikube tunnel` publie tous
  les `LoadBalancer` sur `127.0.0.1` : trois Services sur le même port entreraient en conflit.

## Conséquences

- Une seule version des templates à maintenir ; les différences sont visibles dans trois petits
  fichiers.
- `helm upgrade` avec un fichier de valeurs différent ne modifie que les objets concernés.
- Le type de Service fait partie de l'état géré par Helm : repasser de `LoadBalancer` à
  `ClusterIP` (et inversement) se fait par un `helm upgrade`, pas par `kubectl`.
- La documentation doit indiquer clairement quel fichier de valeurs est utilisé en local et sur
  GKE : ce sont les mêmes.

## Alternatives écartées

- **Un chart par environnement** : duplication, dérive garantie entre dev et prod, et l'énoncé
  l'interdit.
- **Kustomize** : gère bien les surcouches, mais ne fournit ni paquet versionné, ni historique de
  révision, ni `rollback` — exigés par le scénario de démonstration.
- **Des conditions `if` sur l'environnement dans les templates** : rend le chart illisible et
  interdit par l'énoncé (les différences passent uniquement par les fichiers de valeurs).
- **Un second fichier de valeurs par contexte (`values-gke.yaml`)** : possible, mais ajoute un
  fichier à maintenir pour une seule clé ; `--set` est suffisant et visible dans l'historique Helm.

## Dette associée

Le chart ne porte pas d'annotation `checksum/config` sur les Deployments : modifier une ConfigMap
via `helm upgrade` ne redémarre pas les pods (les variables `envFrom` sont lues au démarrage).
Contournement documenté dans le [runbook 3](../runbooks/03-modifier-configuration.md) :
`kubectl rollout restart`. Correctif prévu : ajouter l'annotation dans les templates, ce qui
rendra le runbook purement Helm et idempotent.
