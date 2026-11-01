# Runbook 6 — Vérifier que les données sont persistées

**Quand** : après un déploiement, avant une démonstration, ou pour diagnostiquer une perte de
messages.

## 1. Vérifier le montage et la configuration Redis

```bash
kubectl get pvc -n <env>                                  # attendu : Bound
kubectl exec -n <env> deploy/redis-leader -- redis-cli CONFIG GET dir
# attendu : dir /data
kubectl exec -n <env> deploy/redis-leader -- redis-cli INFO persistence
# attendu : aof_enabled:1
kubectl exec -n <env> deploy/redis-leader -- ls -la /data
# attendu : appendonlydir/ (Redis 7), éventuellement dump.rdb
```

Si le PVC est `Pending` : la StorageClass n'est pas appliquée (champ `storageClassName` écrit vide
dans le manifeste). Voir [ADR 003](../decisions/003-persistance.md).

## 2. Écrire des messages

```bash
curl -s "http://<URL>:<PORT>/guestbook.php?cmd=set&value=message-1,message-2,message-3"
curl -s "http://<URL>:<PORT>/guestbook.php?cmd=get"
# attendu : {"data": "message-1,message-2,message-3"}
```

L'application stocke tous les messages dans une seule clé Redis, séparés par des virgules.

## 3. Supprimer le pod leader

```bash
kubectl get pods -n <env> -l app.kubernetes.io/component=redis-leader
kubectl delete pod -l app.kubernetes.io/component=redis-leader -n <env>
kubectl get pods -n <env> -w          # attendre READY 1/1
```

Sur GKE, le volume doit être détaché puis réattaché : 1 à 2 minutes. Sur minikube, quelques
secondes.

## 4. Relire

```bash
curl -s "http://<URL>:<PORT>/guestbook.php?cmd=get"
# attendu : les trois messages sont toujours là
```

## 5. Tests complémentaires (bonus)

- Après un `helm upgrade` qui modifie le leader : même résultat attendu.
- Après `minikube stop` puis `minikube start` (environnement local) : même résultat attendu.

## Où sont les données

Uniquement dans le volume du leader (`/data` du pod), sur un disque persistant provisionné par la
StorageClass par défaut. Les followers ne stockent rien de durable ; le frontend est sans état.
Un `helm uninstall` supprime le PVC (pas d'annotation `keep`) : les messages de l'environnement
sont perdus avec la release.
