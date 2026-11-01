# Diagnostic et erreurs rencontrées

## Réflexes de base

```bash
kubectl config current-context           # minikube ou GKE ? (piège n°1)
kubectl get pods -n <env> -o wide
kubectl describe pod <pod> -n <env>
kubectl logs deploy/frontend -n <env>
kubectl logs deploy/redis-leader -n <env> --previous
kubectl get events -n <env> --sort-by=.lastTimestamp
kubectl get svc,endpoints -n <env>
kubectl get pvc -n <env>
helm status stack-<env> -n <env>
helm get values stack-<env> -n <env>
helm get manifest stack-<env> -n <env>
```

## Pods bloqués en `Pending`

- **Autopilot** : aucune erreur, le cluster ajoute un nœud (1 à 3 min). Regarder les événements
  avant de conclure à un problème.
- **Ressources** : `kubectl describe pod` affiche `Insufficient cpu/memory` si les demandes
  dépassent ce qui est disponible sur minikube.
- **PVC** : un pod qui attend son volume reste `Pending` avec `pod has unbound immediate
  PersistentVolumeClaims`.

## `ImagePullBackOff`

- Le tag n'existe pas : vérifier le dépôt et le tag dans `values.yaml`.
- L'image frontend est sur `gcr.io/google-samples/gb-frontend:v5` dans le chart, et
  `us-docker.pkg.dev/google-samples/containers/gke/gb-frontend:v5` dans `k8s/`. Les deux existent,
  mais l'écart est une dette à corriger (ADR 006).
- Sur un cluster sans accès Internet sortant, aucun des deux ne se tirera.

## `CrashLoopBackOff` sur Redis

- `redis-cli CONFIG GET dir` échoue, le conteneur redémarre : vérifier le fichier de configuration
  monté (`kubectl exec ... cat /usr/local/etc/redis/redis.conf`) et les droits d'écriture dans
  `/data` (`ls -la /data`).
- `Bad directive or wrong number of arguments` : le fichier `redis.conf` contient des caractères
  de fin de ligne Windows (CRLF). Vérifier avec `file` ou `od -c` ; corriger le fichier et le
  `.gitattributes` (`*.conf text eol=lf`).

## PVC `Pending`

Le champ `storageClassName` est présent mais vide dans le manifeste généré : `""` signifie « aucune
classe », pas « classe par défaut ». Le template doit omettre le champ quand la valeur est vide
(voir ADR 003). Vérifier :

```bash
kubectl get pvc redis-leader-pvc -n <env> -o yaml | grep -i storageclass
kubectl get storageclass
```

## Service sans Endpoints

`kubectl get endpoints frontend -n <env>` renvoie `<none>` : le sélecteur du Service ne correspond
à aucun pod. Vérifier que le label `app.kubernetes.io/component` du Service et celui du pod sont
identiques (et que `instance` correspond au nom de la release).

## Page vide ou erreur 500 sur le frontend

- Le frontend ne joint pas Redis : vérifier `kubectl exec deploy/frontend -- env | grep GET_HOSTS_FROM`
  et la résolution des noms (`getent hosts redis-leader` depuis un pod, si disponible).
- Les noms des Services Redis ont été préfixés (par exemple `stack-dev-guestbook-redis-leader`) :
  le code PHP cherche `redis-leader` et échoue silencieusement côté navigateur. Corriger les
  valeurs `redisLeader.service.name` / `redisFollower.service.name`.
- Le leader est en cours de redémarrage (`Recreate`) : réessayer après `Ready`.

## `helm upgrade` ne redémarre pas les pods

Modifier une ConfigMap ne propage pas les variables d'environnement tant que le conteneur n'est pas
recréé (le chart n'a pas d'annotation `checksum/config`). Solution documentée au
[runbook 3](runbooks/03-modifier-configuration.md) : `kubectl rollout restart`.

## Terraform

| Message | Cause | Solution |
|---|---|---|
| `project = "REMPLACER_PAR_LE_PROJECT_ID_DU_LAB"` | le modèle n'a pas été édité | renseigner `project_id` et `region` dans `terraform.tfvars` |
| `No value for required variable` | `terraform.tfvars` absent | `cp terraform.tfvars.example terraform.tfvars` |
| `Error 403 ... API has not been used` | API non activée | `gcloud services enable container.googleapis.com compute.googleapis.com` |
| `oauth2: invalid_grant Account has been deleted` | credentials ADC d'une ancienne session | `gcloud auth application-default login` |
| `Error 404 ... networks/default` | projet sans VPC par défaut | créer un réseau, passer `network`/`subnetwork` |
| `Error 409: Already Exists` | cluster créé hors du state | `terraform import`, ou supprimer le cluster à la main |
| `terraform destroy` refusé | `deletion_protection = true` | passer `false` dans `terraform.tfvars` |
| `No changes` alors que le cluster n'existe pas | module absent de `main.tf` | vérifier que `main.tf` contient bien l'appel du module |

## gcloud pointe sur une ancienne session

Le projet change à chaque session de lab. `gcloud config get-value project` doit afficher l'ID du
panneau *Lab details*. Sinon `gcloud config set project <ID>`.

## Contexte kubectl

Après `gcloud container clusters get-credentials`, le contexte GKE remplace `minikube` mais
l'ancien contexte reste disponible. Toujours vérifier `kubectl config current-context` avant une
commande Helm ; pour revenir en local, `kubectl config use-context minikube`.

## Temps de lab

Le cluster met 10 à 15 minutes à se créer et 5 à 10 à se détruire. En cas de session courte :
lancer `terraform apply` en premier, faire la démonstration applicative pendant la création, et
lancer `terraform destroy` dès la fin de la démonstration.
