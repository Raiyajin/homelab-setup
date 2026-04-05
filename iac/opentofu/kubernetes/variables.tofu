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

variable "talos_install_image" {
  description = "The talos install image, when updated upgrade the talos machine version"
  type        = string
  default     = "factory.talos.dev/metal-installer/cf391346719bacf6efc5a64471e8de9d59be19683fb93c526360eb2112c51377:v1.12.6"
}

variable "talos_install_image_gpu" {
  description = "The talos install image, when updated upgrade the talos machine version"
  type        = string
  default     = "factory.talos.dev/metal-installer/dc7b152cb3ea99b821fcb7340ce7168313ce393d663740b791c36f6e95fc8586:v1.12.6"
}