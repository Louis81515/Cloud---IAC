# Runbook 1 — Déployer une nouvelle version de l'application

**Quand** : nouvelle image du frontend, ou nouvelle version du chart à livrer sur un environnement.

**Prérequis** : contexte kubectl correct (`kubectl config current-context`), dépôt à jour.

## Commandes

```bash
# 1) Incrémenter la version du chart (SemVer)
#    helm/guestbook/Chart.yaml : version 0.1.0 -> 0.1.1
#    (et appVersion si la version applicative change)

# 2) Contrôler avant de livrer
helm lint helm/guestbook -f helm/guestbook/values-prod.yaml

# 3) Livrer
helm upgrade stack-prod helm/guestbook -n prod -f helm/guestbook/values-prod.yaml

# 4) Suivre
helm status stack-prod -n prod
helm history stack-prod -n prod          # nouvelle révision
kubectl get pods -n prod
```

Pour forcer un redémarrage des pods (nouvelle image, nouveau réglage), modifier une valeur qui
apparaît dans le pod : tag d'image, `resources`, ou variable d'environnement. Un simple incrément
de `version` dans `Chart.yaml` crée une révision Helm mais **ne recrée pas les pods** (le template
des pods ne contient pas `helm.sh/chart`).

## Vérification

```bash
kubectl rollout status deploy/frontend -n prod
kubectl get deploy -n prod                       # READY à jour
curl -s "http://<IP-PROD>:8082/guestbook.php?cmd=get"   # messages toujours présents
```

## Retour arrière

Voir le runbook 2 (`helm rollback`).
