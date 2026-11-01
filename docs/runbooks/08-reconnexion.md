# Runbook 8 — Se reconnecter au cluster depuis un nouveau poste

**Quand** : changement de poste, nouvelle session de lab, ou `kubectl` ne répond plus.

## 1. Installer les outils

```bash
gcloud version            # Google Cloud SDK
gcloud components install gke-gcloud-auth-plugin
gke-gcloud-auth-plugin --version
kubectl version --client
helm version
terraform version
```

Sans le plugin, `kubectl` échoue avec `exec plugin "gke-gcloud-auth-plugin" not found`.

## 2. S'authentifier

```bash
gcloud auth login                      # compte du lab (student-...@qwiklabs.net)
gcloud config set project <PROJECT_ID>
gcloud config get-value project        # doit afficher le projet de la session en cours

# Terraform a besoin des Application Default Credentials (fichier séparé de la config gcloud)
gcloud auth application-default login
gcloud auth application-default print-access-token   # doit renvoyer un jeton
```

Le projet change à **chaque** session de lab : ne pas se fier à un ancien ID.

## 3. Récupérer les credentials du cluster

```bash
# Depuis le dossier terraform (si le state est sur ce poste)
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --location "$(terraform output -raw cluster_region)" \
  --project "$(terraform output -raw project_id)"

# Sinon, retrouver le nom et la région
gcloud container clusters list
```

## 4. Vérifier et choisir le contexte

```bash
kubectl config get-contexts
kubectl config use-context gke_<projet>_<région>_<cluster>
kubectl config current-context
kubectl cluster-info
kubectl get ns
```

## 5. Bascule local / cloud

- minikube : `kubectl config use-context minikube`
- GKE : `kubectl config use-context gke_<projet>_<région>_<cluster>`

**Règle** : vérifier `kubectl config current-context` **avant** tout `helm install` ou
`helm upgrade`. Un chart installé sur le mauvais cluster est le genre d'erreur qui coûte une
session de lab.

## 6. Cas d'erreurs fréquentes

| Message | Cause | Solution |
|---|---|---|
| `exec plugin ... not found` | plugin absent du `PATH` | `gcloud components install gke-gcloud-auth-plugin` |
| `PERMISSION_DENIED` / projet introuvable | projet d'une ancienne session | `gcloud config set project <ID actuel>` |
| `oauth2: invalid_grant Account has been deleted` | ADC d'un ancien compte étudiant | supprimer `~/.config/gcloud/application_default_credentials.json` puis `gcloud auth application-default login` |
| `connection refused` sur l'endpoint | cluster détruit ou IP changée | `gcloud container clusters list`, puis `get-credentials` |
