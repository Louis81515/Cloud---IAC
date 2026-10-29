# main.tf — création du cluster GKE Autopilot.
# Seul le module beta-autopilot-public-cluster est utilisé : aucune ressource
# google_container_cluster écrite à la main. Terraform ne déploie AUCUN objet
# applicatif : le déploiement est entièrement pris en charge par Helm.
# source et version sont les deux seules valeurs littérales (Terraform ne permet pas
# de les variabiliser) ; tous les autres arguments reçoivent une variable.

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version = "~> 46.0" # version du module épinglée

  project_id = var.project_id   # projet du lab, jamais en dur (change à chaque session)
  name       = var.cluster_name # « autopilot-cluster-1 »
  region     = var.region       # région fournie par le lab (Autopilot = cluster régional)
  network    = var.network      # réseau VPC par défaut du projet de lab
  subnetwork = var.subnetwork   # sous-réseau par défaut de la région

  ip_range_pods     = var.ip_range_pods     # null : plages secondaires gérées par GKE
  ip_range_services = var.ip_range_services # idem

  release_channel     = var.release_channel     # REGULAR : canal de mise à jour GKE
  deletion_protection = var.deletion_protection # false : permet terraform destroy en fin de lab
}
