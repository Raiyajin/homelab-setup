variable "talos_version" {
  description = "Talos version"
  type        = string
  default     = "1.12.6"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35.0"
}

variable "cluster_name" {
  description = "Kubernetes Cluster name"
  type        = string
  default     = "kubernetes"
}
