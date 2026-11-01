# Soutenance — scénario de démonstration

Format : 30 à 45 minutes. 10 à 15 minutes de présentation, environ 15 minutes de démonstration,
10 à 15 minutes de questions. La présentation est une réunion de passation, pas un cours : on
présente la plateforme, les choix et la façon de l'exploiter.

## Répartition (3 membres)

| Partie | Membre | Durée |
|---|---|---|
| Contexte, architecture, Terraform, frontière avec Helm | A | 4 min |
| Kubernetes, persistance, stratégie `Recreate`, probes | B | 4 min |
| Chart Helm, environnements, local vs cloud, limites | C | 4 min |

Pendant la démonstration, chaque étape est pilotée par le membre qui connaît le mieux la partie,
mais l'examinateur peut demander à n'importe qui de dérouler un runbook.

## À préparer avant la soutenance

- Session de lab lancée, `terraform apply` exécuté en amont (10-15 min de création).
- Dépôt cloné, terminal positionné à la racine du dépôt.
- **minikube démarré et `minikube tunnel` déjà lancé** (terminal administrateur), avec les trois
  releases installées : sinon l'étape 9 prend plusieurs minutes.
- `terraform output` gardé sous la main (nom du cluster, région, commande de connexion).
- Vidéo de secours de la démonstration, et captures des résultats attendus.
- Un onglet ouvert sur `docs/runbooks/` pour dérouler un runbook à la demande.

## Démonstration (10 étapes imposées)

| # | Étape | Commandes | Résultat attendu | Temps |
|---|---|---|---|---|
| 1 | Idempotence Terraform | `cd terraform && terraform plan` ; `terraform output` | `No changes` ; nom, région et commande de connexion affichés | 1 min |
| 2 | Connexion au cluster | `gke-gcloud-auth-plugin --version` ; `gcloud container clusters get-credentials …` ; `kubectl cluster-info` | contexte `gke_…`, plan de contrôle joignable | 1 min |
| 3 | `dev` en ClusterIP + port-forward | `helm install stack-dev … --set frontend.service.type=ClusterIP` ; `kubectl port-forward svc/frontend 8080:8080 -n dev` | page du livre d'or accessible, messages ajoutés | 3 min |
| 4 | Ouverture | `helm upgrade stack-dev …` ; `kubectl get svc frontend -n dev -w` | `EXTERNAL-IP` renseignée, page accessible sur l'IP publique | 3 min |
| 5 | `staging` et `prod` | deux `helm install` ; `helm list -A` | trois releases `deployed` | 2 min |
| 6 | Persistance | ajouter 3 messages ; `kubectl delete pod -l app.kubernetes.io/component=redis-leader -n prod` ; relire | pod recréé, messages toujours présents | 2 min |
| 7 | Montée de version + rollback | `helm upgrade` avec une version de chart incrémentée ; `helm history` ; `helm rollback` | nouvelle révision, messages conservés | 2 min |
| 8 | Objets Kubernetes | `kubectl describe deploy redis-leader -n prod` ; `describe deploy frontend` | probes, requests/limits, stratégie `Recreate` visibles | 2 min |
| 9 | Parité locale | `kubectl config use-context minikube` ; `kubectl get svc -A` ; navigation | mêmes objets, mêmes URLs (8080/8081/8082) | 2 min |
| 10 | Nettoyage | `helm uninstall` ×3 ; `terraform destroy` | releases supprimées, cluster détruit | en fond |

Astuce de timing : lancer `terraform destroy` à la fin de l'étape 9, puis répondre aux questions
pendant la destruction. Les étapes 3 à 5 peuvent se chevaucher : pendant que le load balancer de
`dev` se provisionne, installer `staging` et `prod`.

## Questions probables et réponses courtes

1. **Pourquoi `Recreate` sur le leader ?** Volume `ReadWriteOnce` et un seul écrivain Redis : un
   `RollingUpdate` créerait deux pods sur le même disque (`Multi-Attach` ou double écriture).
2. **Pourquoi `ReadWriteOnce` et pas `ReadWriteMany` ?** Un seul écrivain ; RWX ne résout pas le
   problème applicatif et coûte plus cher.
3. **Pourquoi ne pas écrire `storageClassName: ""` ?** Cette valeur signifie « aucune classe » et
   laisse le PVC `Pending` ; le champ doit être absent pour utiliser la classe par défaut.
4. **Pourquoi les Services Redis ont-ils des noms fixes ?** Les images codent `redis-leader` et
   `redis-follower` en dur (mode `dns`) ; les namespaces assurent l'isolation entre environnements.
5. **Pourquoi un state Terraform local ?** Projet de lab éphémère, un opérateur ; un backend GCS
   serait la cible en entreprise.
6. **Pourquoi Terraform ne déploie-t-il pas l'application ?** Séparation infrastructure /
   applicatif : terraform gère le cluster, Helm gère les objets Kubernetes.
7. **Que devient le PVC au `helm uninstall` ?** Il est supprimé (pas d'annotation `keep`), donc les
   messages de l'environnement sont perdus.
8. **Comment agrandir un volume ?** Modifier `persistence.size`, `helm upgrade`, puis vérifier le
   PVC ; l'expansion dépend de `allowVolumeExpansion` de la StorageClass.
9. **Comment une modification de ConfigMap atteint-elle les pods ?** Pas automatiquement : il
   manque l'annotation `checksum/config`, le runbook 3 impose `kubectl rollout restart`.
10. **Que fait `helm rollback` ?** Il réinstalle une révision précédente et crée une nouvelle
    révision ; le PVC n'est pas recréé.
11. **Différence entre readiness et liveness ?** La readiness retire le pod du Service s'il ne peut
    pas servir ; la liveness redémarre le conteneur s'il est bloqué.
12. **Différences dev/staging/prod ?** Réplicas, ressources, taille de volume, port du Service et
    label `environment` ; même chart, mêmes templates.
13. **Pourquoi GKE Autopilot ?** Imposé par l'énoncé ; pas de gestion des node pools, facturation à
    la ressource demandée.
14. **Qu'est-ce qui manque pour la production ?** Haute disponibilité Redis, sauvegardes, TLS,
    secrets, observabilité, un cluster par environnement.
15. **Comment ajouter un environnement ?** Créer le namespace, un `values-<env>.yaml`, puis
    `helm install stack-<env>` ; aucun template à modifier.
16. **Comment les followers se synchronisent-ils ?** `redis-server --replicaof redis-leader 6379`,
    réplication native Redis ; ils se resynchronisent après un redémarrage du leader.
17. **Que se passe-t-il si le leader tombe ?** Le pod est recréé (Deployment), le volume est
    réattaché, Redis rejoue le journal AOF ; les écritures sont indisponibles pendant ce temps.
18. **Pourquoi deux registres d'images différents ?** Dette connue : le chart utilise `gcr.io`, les
    manifestes bruts `us-docker.pkg.dev` ; les deux images existent, à harmoniser (ADR 006).

## Ce que l'examinateur peut vérifier sans vous

```bash
helm list -A
terraform plan
kubectl get all,cm,pvc -n prod --show-labels
kubectl get deploy redis-leader -n prod -o jsonpath='{.spec.strategy.type}'
kubectl get pvc -n prod
kubectl describe deploy redis-leader -n prod
```

Toutes ces commandes doivent fonctionner et donner les résultats décrits dans ce README et dans
`docs/runbooks/`.
