# Runbook 2 — Revenir à la révision précédente

**Quand** : une mise à jour vient de casser l'application ou de dégrader un environnement.

**Prérequis** : au moins deux révisions dans l'historique de la release.

## Commandes

```bash
# 1) Voir l'historique
helm history stack-prod -n prod

# 2) Revenir à la révision précédente (numéro donné par la colonne REVISION)
helm rollback stack-prod 3 -n prod

# 3) Suivre
helm status stack-prod -n prod
helm history stack-prod -n prod          # une nouvelle révision est créée par le rollback
```

`helm rollback` crée une **nouvelle** révision : on ne « supprime » jamais d'historique.

## Vérification

```bash
kubectl get pods -n prod
kubectl rollout status deploy/frontend -n prod
helm get values stack-prod -n prod       # valeurs réellement appliquées
```

Les données ne sont pas concernées : le PVC n'est pas recréé par un rollback. Vérifier malgré tout :

```bash
curl -s "http://<IP-PROD>:8082/guestbook.php?cmd=get"
```

## Si le rollback ne suffit pas

Revenir à une version connue du dépôt, puis relancer le runbook 1 avec les valeurs de cette
version. En dernier recours, `helm uninstall` puis réinstallation — mais cela supprime le PVC et
donc les messages de l'environnement.
