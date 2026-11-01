# Runbook 3 — Modifier la configuration d'un environnement

**Quand** : changer une variable d'environnement, une valeur de ressource, un port, une taille de
volume — tout ce qui vit dans `values-<ENV>.yaml`.

**Prérequis** : fichier de valeurs de l'environnement dans `helm/guestbook/`.

## Commandes

```bash
# 1) Modifier UNIQUEMENT les surcharges utiles dans
#    helm/guestbook/values-<env>.yaml
#    (ne pas recopier tout values.yaml)

# 2) Contrôler
helm lint helm/guestbook -f helm/guestbook/values-<env>.yaml
helm template stack-<env> helm/guestbook -n <env> -f helm/guestbook/values-<env>.yaml | head -40

# 3) Appliquer
helm upgrade stack-<env> helm/guestbook -n <env> -f helm/guestbook/values-<env>.yaml
```

## Cas particulier : variables d'environnement (ConfigMap)

Le chart ne porte pas l'annotation `checksum/config` : `helm upgrade` met bien la ConfigMap à jour,
mais les pods ne redémarrent pas et gardent les anciennes variables (`envFrom` est lu au démarrage
du conteneur). Il faut donc redémarrer explicitement :

```bash
kubectl rollout restart deploy/frontend -n <env>
kubectl rollout status deploy/frontend -n <env>
```

C'est le seul cas du projet où une commande `kubectl` modifie un environnement partagé. Le
correctif prévu est d'ajouter l'annotation dans les templates (dette technique, README §9).

## Vérification

```bash
kubectl exec -n <env> deploy/frontend -- env | grep GET_HOSTS_FROM
kubectl get cm frontend-config -n <env> -o yaml
helm get values stack-<env> -n <env>
```

## Retour arrière

`helm rollback stack-<env> <révision précédente> -n <env>` (runbook 2). Si seule une variable
d'environnement a changé, le rollback met la ConfigMap à jour mais ne redémarre pas les pods :
relancer `kubectl rollout restart`.
