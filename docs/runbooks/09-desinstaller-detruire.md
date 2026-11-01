# Runbook 9 — Désinstaller les releases puis détruire le cluster

**Quand** : fin de session de lab, ou remise à zéro complète.

**Ordre imposé** : les releases Helm d'abord, le cluster ensuite. Terraform ne connaît pas les
objets Helm ; détruire le cluster d'abord laisserait des ressources orphelines dans le state Helm
(et le state Terraform ne serait plus cohérent avec ce qui reste).

## 1. Désinstaller les releases

```bash
helm list -A

helm uninstall stack-dev     -n dev
helm uninstall stack-staging -n staging
helm uninstall stack-prod    -n prod

helm list -A                          # attendu : plus aucune release
kubectl get all,cm,pvc -n dev         # attendu : rien (hormis les objets système)
```

**Attention** : `helm uninstall` supprime le PVC `redis-leader-pvc` (pas d'annotation
`helm.sh/resource-policy: keep`) : les messages de l'environnement sont perdus. Pour conserver le
volume avant une désinstallation, l'annoter au préalable :

```bash
kubectl annotate pvc redis-leader-pvc -n prod helm.sh/resource-policy=keep
# puis, pour le réutiliser après réinstallation : retirer l'annotation, ou recréer la release
# avec un PVC existant (le nom du PVC est fixe)
```

## 2. Détruire le cluster

```bash
cd terraform
terraform plan -destroy               # vérifier que seules les 7 ressources sont supprimées
terraform destroy                     # 5 à 10 minutes
```

`deletion_protection` doit valoir `false` dans `terraform.tfvars` (valeur par défaut du projet) ;
sinon GKE refuse la suppression.

## 3. Vérifier

```bash
gcloud container clusters list        # attendu : aucune ligne
terraform state list                  # attendu : vide
```

S'il reste quelque chose, c'est que le state a été perdu ou que la destruction a échoué : relancer
`terraform destroy`, et en dernier recours supprimer le cluster à la console.

## 4. Ce qui n'est pas nettoyé automatiquement

- Les images tirées par les nœuds : supprimées avec le cluster.
- Le kubeconfig local : l'entrée du contexte GKE reste dans `~/.kube/config` (sans effet).
- Le state Terraform local et `terraform.tfvars` : à conserver pour la session suivante, ou à
  supprimer si le projet est abandonné.
