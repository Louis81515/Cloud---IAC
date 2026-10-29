# outputs.tf — sorties utiles à l'exploitation du cluster.
# Les valeurs sont lues dans les outputs du module (pas recopiées depuis les variables),
# à une exception documentée : project_id, que le module n'expose pas.

output "cluster_name" {
  description = "Nom du cluster GKE Autopilot créé (lu dans le module)."
  value       = module.gke.name
}

output "cluster_region" {
  description = "Région du cluster (Autopilot = cluster régional)."
  value       = module.gke.region
}

output "project_id" {
  description = "Projet GCP dans lequel le cluster a été créé. Exception : le module n'expose pas d'output projet, on relit donc l'entrée."
  value       = var.project_id
}

output "cluster_endpoint" {
  description = "Endpoint du plan de contrôle Kubernetes (adresse de l'API)."
  value       = module.gke.endpoint
  sensitive   = true
}

output "kubernetes_version" {
  description = "Version de Kubernetes du plan de contrôle."
  value       = module.gke.master_version
}

output "release_channel" {
  description = "Canal de release effectivement appliqué au cluster."
  value       = module.gke.release_channel
}

output "connection_command" {
  description = "Commande prête à copier pour récupérer les credentials du cluster dans kubectl."
  value       = "gcloud container clusters get-credentials ${module.gke.name} --location ${module.gke.region} --project ${var.project_id}"
}
