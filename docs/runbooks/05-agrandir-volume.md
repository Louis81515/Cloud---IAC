# Runbook 5 — Agrandir le volume persistant

**Quand** : le volume des messages approche de sa taille maximale.

**Prérequis** : la StorageClass doit autoriser l'expansion (`allowVolumeExpansion: true`).

## Commandes

```bash
# 1) Vérifier la classe et son support de l'expansion
kubectl get pvc redis-leader-pvc -n <env> -o jsonpath='{.spec.storageClassName}'
kubectl get storageclass <classe> -o jsonpath='{.allowVolumeExpansion}'

# 2) Augmenter la taille dans helm/guestbook/values-<env>.yaml :
#    redisLeader.persistence.size: 5Gi -> 10Gi

# 3) Appliquer
helm upgrade stack-<env> helm/guestbook -n <env> -f helm/guestbook/values-<env>.yaml

# 4) Suivre l'expansion
kubectl get pvc redis-leader-pvc -n <env> -w
kubectl describe pvc redis-leader-pvc -n <env>   # Conditions / Events
```

## Résultats attendus

- **GKE** (`standard-rwo`, `allowVolumeExpansion: true`) : le PVC passe à la nouvelle taille, puis
  le système de fichiers est étendu. Compter quelques minutes, et un redémarrage du pod si le
  redimensionnement du système de fichiers en ligne n'est pas possible.
- **minikube** (`standard`, hostPath) : l'expansion n'est généralement pas autorisée. Le PVC ne
  grossit pas ; le seul contournement est de recréer le volume (donc les données) ou de migrer
  vers une classe qui l'autorise.

## Vérification

```bash
kubectl get pvc redis-leader-pvc -n <env>
kubectl exec -n <env> deploy/redis-leader -- df -h /data
```

## Limites

- Un PVC ne peut **jamais** être réduit.
- L'augmentation ne modifie pas le contenu du volume : les messages sont conservés.
- Le PVC n'est pas conservé lors d'un `helm uninstall` (pas d'annotation `keep`) : un agrandissement
  ne protège pas contre une désinstallation.
