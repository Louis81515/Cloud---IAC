# Runbook 4 — Augmenter les réplicas ou les ressources d'un composant

**Quand** : charge en hausse, ou ajustement après observation de la consommation.

## Commandes

```bash
# 1) Dans helm/guestbook/values-<env>.yaml, modifier un ou plusieurs blocs :
#    frontend.replicaCount
#    redisFollower.replicaCount           (le leader reste à 1, voir ADR 002)
#    frontend.resources.requests / limits
#    redisLeader.resources / redisFollower.resources

# 2) Contrôler puis appliquer
helm lint helm/guestbook -f helm/guestbook/values-<env>.yaml
helm upgrade stack-<env> helm/guestbook -n <env> -f helm/guestbook/values-<env>.yaml
```

## Vérification

```bash
kubectl get deploy -n <env>                      # colonne READY = réplicas désirés
kubectl describe deploy frontend -n <env>        # Requests/Limits à jour
kubectl get pods -n <env> -o wide
```

Un changement de `resources` modifie le template du pod : les pods sont recréés avec un
`RollingUpdate` (frontend, follower) ou un `Recreate` (leader, avec une courte interruption).

## Retour arrière

Remettre les valeurs précédentes et relancer `helm upgrade`, ou `helm rollback` (runbook 2).

## Attention

Sur GKE **Autopilot**, les requêtes inférieures aux minimums d'Autopilot sont arrondies à la
hausse : une configuration à `100m` de CPU peut être facturée au minimum Autopilot. Sur minikube,
vérifier que le nœud a assez de mémoire avant d'augmenter les réplicas.
