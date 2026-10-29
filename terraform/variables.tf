# variables.tf — toutes les variables d'entrée du projet.
# Seul fichier autorisé à contenir des blocs `variable` (pas main.tf, pas versions.tf).
# Les valeurs réelles de la session de lab vont dans terraform.tfvars (non versionné).
# Chaque variable porte un type et une description ; seules project_id et region n'ont
# pas de default : elles changent à chaque session de lab.

variable "project_id" {
  description = "ID du projet GCP fourni par le lab Google Skills (change à chaque session). Exemple : qwiklabs-gcp-01-abc123. Récupérable avec gcloud config get-value project."
  type        = string
  # PAS de default : valeur obligatoire, propre à chaque session de lab.
}

variable "cluster_name" {
  description = "Nom du cluster GKE Autopilot (argument `name` du module). Autopilot est régional : la zone est portée par `region`."
  type        = string
  default     = "autopilot-cluster-1"
}

variable "region" {
  description = "Région GCP du cluster (cluster régional Autopilot). Exemple : us-central1. Fournie par le panneau du lab."
  type        = string
  # PAS de default : change à chaque session de lab.

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region doit être au format d'une région GCP, par exemple us-central1."
  }
}

variable "network" {
  description = "Nom du réseau VPC dans lequel créer le cluster. \"default\" = réseau par défaut du projet de lab."
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Nom du sous-réseau régional utilisé par le cluster. \"default\" = sous-réseau par défaut de la région."
  type        = string
  default     = "default"
}

variable "ip_range_pods" {
  description = "Plage secondaire réservée aux pods. null = plages gérées automatiquement par GKE Autopilot."
  type        = string
  default     = null
}

variable "ip_range_services" {
  description = "Plage secondaire réservée aux Services. null = plages gérées automatiquement par GKE Autopilot."
  type        = string
  default     = null
}

variable "release_channel" {
  description = "Canal de mise à jour de GKE : RAPID, REGULAR ou STABLE."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel doit valoir RAPID, REGULAR ou STABLE."
  }
}

variable "deletion_protection" {
  description = "Protection contre la suppression du cluster. false = autorise terraform destroy en fin de session de lab."
  type        = bool
  default     = false
}
