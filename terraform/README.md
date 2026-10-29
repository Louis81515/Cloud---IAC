# Terraform — cluster GKE Autopilot « Livre d'or Cloud »

> **Documentation de transfert.** Ce dossier est la seule source de vérité pour
> l'infrastructure cloud du projet. Point d'entrée de la documentation : [`../README.md`](../README.md).
> Public visé : un consultant qui reprend l'exploitation, connaît Terraform et GCP, mais pas ce projet.

---

## 1. Rôle et périmètre

Ce dossier crée **un seul objet d'infrastructure** : un **cluster GKE Autopilot régional** dans le
projet GCP temporaire fourni par le lab Google Skills.

Il ne crée **aucun objet Kubernetes applicatif** (deployment, service, ConfigMap, PVC) : tout le
déploiement de l'application est pris en charge par **Helm** (dossier `helm/`). C'est la frontière
posée par l'énoncé :

| Outil | Responsabilité | Ne fait pas |
|---|---|---|
| **Terraform** (`terraform/`) | cluster GKE, compte de service, IAM | aucun objet dans le cluster |
| **Helm** (`helm/guestbook/`) | déploiement de l'application, 3 environnements | aucune ressource GCP |

Conséquence pratique : `terraform destroy` détruit le cluster et donc tout ce qu'il contient, mais
Terraform ne sait pas ce que Helm y a installé. Le bon ordre de fin de session est donc
`helm uninstall` **puis** `terraform destroy`.

Le cluster est **reconstructible à l'identique** : sur un projet vierge, `terraform apply` recrée
le même cluster (même nom, même région, même canal), et il ne reste qu'à réinstaller le chart.

---

## 2. Ce que le module crée réellement

Le module imposé `terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster`
(version **46.0.0**) crée, **avec la configuration de ce dossier**, 7 ressources :

| # | Adresse Terraform (`terraform state list`) | Rôle |
|---|---|---|
| 1 | `module.gke.google_container_cluster.primary` | Le cluster **Autopilot** (`enable_autopilot = true`) : plan de contrôle et nœuds gérés par Google |
| 2 | `module.gke.random_shuffle.available_zones` | Tirage de 3 zones de la région (Autopilot = cluster régional) |
| 3 | `module.gke.random_string.cluster_service_account_suffix` | Suffixe aléatoire de 4 caractères du compte de service |
| 4 | `module.gke.google_service_account.cluster_service_account` | Compte de service des nœuds, nommé `tf-gke-autopilot-cluste-<suffixe>` |
| 5 | `module.gke.google_project_iam_member.cluster_service_account_node_service_account` | Rôle `roles/container.defaultNodeServiceAccount` |
| 6 | `module.gke.google_project_iam_member.cluster_service_account_metric_writer` | Rôle `roles/monitoring.metricWriter` (métriques des nœuds) |
| 7 | `module.gke.google_project_iam_member.cluster_service_account_resource_metadata_writer` | Rôle `roles/stackdriver.resourceMetadata.writer` |

Le module lit aussi des **data sources** : zones disponibles dans la région et versions de GKE
disponibles (aucune ressource créée).

> **Vérification après `apply` :** `terraform state list` doit afficher ces 7 adresses.
> `terraform plan` liste les mêmes ressources avec leurs attributs.

### Ressources que le module *sait* créer mais qui sont **désactivées** ici

Ces ressources n'apparaîtront pas dans le plan. Elles sont documentées pour que l'absence de
certaines ressources (par exemple les règles de firewall) ne soit pas prise pour un oubli :

| Ressource du module | Variable de contrôle | Valeur ici | Pourquoi |
|---|---|---|---|
| Règles firewall additionnelles (`intra_egress`, `master_webhooks`) | `add_cluster_firewall_rules`, `add_master_webhook_firewall_rules` | `false` | Réseau par défaut du lab, Autopilot gère le nécessaire |
| Règles firewall « shadow » (journalisation) | `add_shadow_firewall_rules` | `false` | Pas de valeur ajoutée en lab |
| Bindings Artifact Registry / GCR du compte de service | `grant_registry_access` | `false` | Les images sont publiques |
| Service agent GKE Hub (Fleet) | `fleet_project_grant_service_agent` | `false` | Pas de gestion multi-cluster |
| Règles firewall TPU | `enable_tpu` | `false` | Non utilisé |

Le **VPC n'est pas créé** non plus : `network = "default"` et `subnetwork = "default"` désignent le
réseau par défaut fourni avec le projet de lab. Si votre projet n'a pas de réseau par défaut,
voir §11.

---

## 3. Fichiers du dossier

| Fichier | Rôle |
|---|---|
| `versions.tf` | `required_version` + `required_providers` (versions épinglées) et configuration des providers `google` / `google-beta` |
| `variables.tf` | Les **9** variables d'entrée, avec `type`, `description` et `validation` ; seul fichier contenant des blocs `variable` |
| `main.tf` | Appel du module GKE (11 arguments, chacun commenté) |
| `outputs.tf` | Les 7 sorties d'exploitation |
| `terraform.tfvars.example` | **Modèle** versionné des valeurs de session |
| `terraform.tfvars` | Valeurs réelles de la session — **non versionné** (`.gitignore`) |
| `.terraform.lock.hcl` | Versions exactes + empreintes des providers — **versionné** |
| `README.md` | Ce document |

---

## 4. Providers

Déclarés une seule fois, dans `versions.tf`.

| Provider | Source | Contrainte | Version installée | Usage |
|---|---|---|---|---|
| `google` | `hashicorp/google` | `~> 8.0` | **8.9.0** | cluster, compte de service, IAM |
| `google-beta` | `hashicorp/google-beta` | `~> 8.0` | **8.9.0** | ressources bêta du module |
| `kubernetes` | `hashicorp/kubernetes` | `~> 2.10` | **2.38.0** | requis par le module (non utilisé directement ici) |
| `random` | `hashicorp/random` | `~> 3.0` | **3.9.1** | suffixes et choix des zones |

Les contraintes retenues sont **compatibles avec celles du module v46.0.0**
(`google`/`google-beta` `>= 7.28, < 9`, `kubernetes` `>= 2.10, < 4`, `random` `>= 2.1`).
En cas de doute : `terraform providers` affiche l'arbre des contraintes (racine + module).

`random` est une dépendance transitive du module ; il est déclaré explicitement pour que
`required_providers` soit exhaustif et que sa version soit figée comme les autres.

Le fichier `.terraform.lock.hcl` est **versionné** : il fige les versions exactes et les empreintes
des providers, ce qui garantit que deux postes (Windows, Cloud Shell Linux) téléchargent des
binaires identiques. Il est normal que `terraform init` le complète lors du premier passage sur une
nouvelle plateforme (ajout des empreintes de la plateforme).

---

## 5. Variables

Déclarées uniquement dans `variables.tf`. Les valeurs sont fournies par `terraform.tfvars`.

| Nom | Type | Défaut | Obligatoire | Rôle |
|---|---|---|---|---|
| `project_id` | string | — | **oui** | ID du projet GCP du lab (change à chaque session) |
| `cluster_name` | string | `autopilot-cluster-1` | non | Nom du cluster (argument `name` du module) |
| `region` | string | — | **oui** | Région du lab ; validée au format `xx-yyyyN` |
| `network` | string | `default` | non | VPC du cluster |
| `subnetwork` | string | `default` | non | Sous-réseau régional |
| `ip_range_pods` | string | `null` | non | `null` = plages secondaires gérées par GKE |
| `ip_range_services` | string | `null` | non | `null` = idem |
| `release_channel` | string | `REGULAR` | non | Canal GKE, limité par `validation` à `RAPID`/`REGULAR`/`STABLE` |
| `deletion_protection` | bool | `false` | non | `false` = autorise `terraform destroy` en fin de lab |

> `project_id` et `region` n'ont **volontairement pas de default** : ce sont les deux valeurs qui
> changent à chaque session de lab, et il vaut mieux une erreur explicite qu'un cluster créé dans
> le mauvais projet.

---

## 6. Outputs

| Nom | Description | Exemple de valeur |
|---|---|---|
| `cluster_name` | Nom du cluster (lu dans le module) | `autopilot-cluster-1` |
| `cluster_region` | Région du cluster | `us-central1` |
| `project_id` | Projet GCP du cluster | `qwiklabs-gcp-01-1a2b3c4d5e6f` |
| `cluster_endpoint` | Endpoint du plan de contrôle, **sensible** | `(sensitive value)` → `34.120.45.67` |
| `kubernetes_version` | Version du plan de contrôle | `1.33.5-gke.1048000` |
| `release_channel` | Canal appliqué | `REGULAR` |
| `connection_command` | Commande de connexion prête à copier | `gcloud container clusters get-credentials autopilot-cluster-1 --location us-central1 --project qwiklabs-...` |

Toutes les valeurs sont lues dans les outputs du module, **à une exception documentée** :
`project_id`, que le module n'expose pas, est relu depuis la variable d'entrée.

L'endpoint est marqué `sensitive = true` : il ne s'affiche pas dans `terraform output` et se lit
avec `terraform output -raw cluster_endpoint`.

---

## 7. Utilisation

### 7.1 Prérequis

- Terraform **>= 1.3** (testé avec 1.17).
- `gcloud` authentifié sur le projet du lab (dans **Cloud Shell**, l'authentification est déjà en place).
- APIs `container.googleapis.com` et `compute.googleapis.com` activées.
- Plugin `gke-gcloud-auth-plugin` installé (`gke-gcloud-auth-plugin --version`).
- Un réseau VPC `default` avec un sous-réseau dans la région choisie.

### 7.2 Déroulé d'une session (Cloud Shell)

```bash
cd terraform

# 1) Valeurs de la session
cp terraform.tfvars.example terraform.tfvars
# éditer project_id et region avec les valeurs du panneau « Lab details »

# 2) Contrôles
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan                 # doit lister 7 ressources à créer

# 3) Création (≈ 10-15 min)
terraform apply

# 4) Sorties
terraform output
terraform output -raw cluster_name
terraform output -raw cluster_region
```

### 7.3 Connexion de kubectl

```bash
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --location "$(terraform output -raw cluster_region)" \
  --project "$(terraform output -raw project_id)"

kubectl config current-context     # gke_<projet>_<région>_<cluster>
kubectl cluster-info
kubectl get namespaces
```

`terraform output -raw connection_command` réaffiche cette commande si besoin.

### 7.4 Vérifier l'idempotence

```bash
terraform plan
# Attendu : « No changes. Your infrastructure matches the configuration. »
```

### 7.5 Destruction

```bash
# Toujours désinstaller les releases Helm AVANT de détruire le cluster
helm uninstall stack-dev stack-staging stack-prod -n ... # voir helm/README
terraform destroy          # ≈ 5-10 min
```

`deletion_protection = false` est indispensable : avec la valeur par défaut de GKE, la destruction
du cluster est bloquée.

---

## 8. State Terraform

**Choix : state local** (`terraform.tfstate` à côté du code), non versionné.

Justification : le projet de lab est éphémère, le cluster vit quelques heures, et un seul opérateur
lance Terraform à la fois. Un backend distant ajouterait des ressources (bucket GCS) à créer et à
détruire à chaque session, pour un bénéfice nul dans ce contexte.

Risques assumés et règles d'usage :

- **Perdre le state = perdre le lien avec l'infrastructure.** Un `terraform destroy` ne saurait plus
  quoi supprimer, et le cluster resterait facturé jusqu'à la fin du projet de lab (qui est de toute
  façon supprimé en fin de session). Sauvegarde simple : copier `terraform.tfstate` avec le dépôt ?
  **Non** — il contient des identifiants de ressources, jamais dans Git.
- **Pas de verrouillage** : deux `apply` simultanés corrompent le state. Règle d'équipe : un seul
  opérateur Terraform à la fois, annoncé dans le canal de l'équipe.
- **State non partagé** : un poste qui n'a pas le state ne peut pas piloter le cluster ; il faut
  récupérer le fichier ou travailler toujours depuis le même poste / la même session Cloud Shell.

**Cible en entreprise (hors périmètre du lab)** : backend distant GCS avec verrouillage natif,
un state par environnement, et exécution en CI avec un compte de service dédié :

```hcl
# Exemple de ce qu'il faudrait ajouter (non implémenté ici)
terraform {
  backend "gcs" {
    bucket = "<projet>-tfstate"
    prefix = "gke/autopilot-cluster-1"
  }
}
```

Le fichier `.terraform.lock.hcl`, lui, **est** versionné (voir §4).

---

## 9. Idempotence et dérives connues

- Après `apply`, `terraform plan` doit répondre **`No changes`**. C'est le critère d'idempotence de
  l'énoncé.
- Dérive possible : GKE met à jour automatiquement le plan de contrôle sur le canal `REGULAR`
  (montée de version mineure). Un `plan` peut alors proposer un changement de version ; ce n'est pas
  une erreur de configuration. À documenter si cela se produit pendant le projet.
- Ne jamais modifier le cluster à la main (console GCP, `gcloud container clusters update`) : la
  modification serait écrasée au prochain `apply` ou créerait une dérive.

---

## 10. Diagnostic — erreurs fréquentes

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Error 403: ... API has not been used in project ...` | API GCP non activée | `gcloud services enable container.googleapis.com compute.googleapis.com` |
| `Error 404: The resource 'projects/.../global/networks/default' was not found` | Projet sans VPC par défaut | Créer un réseau et passer `network` / `subnetwork` en variables |
| `No value for required variable` | `terraform.tfvars` absent | `cp terraform.tfvars.example terraform.tfvars` et renseigner |
| `could not find default credentials` | Pas d'ADC sur le poste | `gcloud auth application-default login` (ou travailler en Cloud Shell) |
| `terraform init` : conflit de versions de provider | `versions.tf` incompatible avec le module | Aligner sur les contraintes du module (`terraform providers`) |
| `Error 409: Already Exists` | Cluster existant (state perdu) | `terraform import` (voir doc Terraform) ou supprimer le cluster à la main |
| `terraform destroy` bloqué | `deletion_protection = true` | Vérifier `terraform.tfvars`, passer `false`, relancer |
| `kubectl` : `exec plugin ... gke-gcloud-auth-plugin not found` | Plugin absent du `PATH` | `gcloud components install gke-gcloud-auth-plugin` |
| `kubectl` pointe sur le mauvais cluster | Contexte non basculé | `kubectl config get-contexts` puis `use-context` |

---

## 11. Limites connues et dette technique

- **State local** : pas de backend distant, pas de verrou, pas de CI (voir §8).
- **Un seul cluster** pour les trois environnements : `dev`, `staging` et `prod` sont des
  **namespaces**, pas des clusters. C'est le choix du sujet (coût et temps de lab), pas une
  architecture de production.
- **Pas de VPC dédié** : réseau par défaut, pas de plage IP maîtrisée, pas de Cloud NAT, pas d'IP
  statique pour l'ingress.
- **Pas de sauvegarde** du cluster ni de ses volumes : la persistance des messages est assurée par
  le PVC applicatif (voir `k8s/` et `helm/`), pas par Terraform.
- **Autopilot** : aucun contrôle sur les node pools (machine type, autoscaling) — c'est le principe
  d'Autopilot.
- **Pas de secret management** (Secret Manager, Workload Identity non configurés).
- **Durée du lab** : le projet et le cluster sont détruits à la fin de la session ; le cluster doit
  être recréé à chaque session (`apply` ≈ 10-15 min).

---

## 12. Références

- Module : [terraform-google-modules/kubernetes-engine — beta-autopilot-public-cluster](https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest/submodules/beta-autopilot-public-cluster)
- Accès au cluster : [Google Cloud — Installer les plug-ins requis et stocker les informations du cluster pour kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl)
- State distant : [Terraform — Backend GCS](https://developer.hashicorp.com/terraform/language/backend/gcs)
- Énoncé et contexte du projet : [`../README.md`](../README.md)
