variable "project_name" {
	description = "Name of the project."
	type        = string
	default     = "cloud-iac"
}

variable "environment" {
	description = "Deployment environment (for example, dev, staging, or prod)."
	type        = string
	default     = "dev"
}

variable "region" {
	description = "Cloud provider region for the deployment."
	type        = string
	default     = "us-east-1"
}

variable "cluster_name" {
	description = "Name of the Kubernetes cluster."
	type        = string
	default     = "cloud-iac-cluster"
}

variable "kubernetes_version" {
	description = "Kubernetes version for the cluster."
	type        = string
	default     = "1.29"
}
