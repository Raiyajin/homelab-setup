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

variable "github_repository" {
  description = "Public github repository https address to use for argo cd"
  type        = string
}

variable "approle_role_id" {
  description = "OpenBao/Vault AppRole role id"
  type        = string
}

variable "approle_secret_id" {
  description = "OpenBao/Vault AppRole secret id"
  type        = string
}

variable "approle_login_path" {
  description = "OpenBao/Vault AppRole login path"
  type        = string
  default     = "auth/approle/login"
}

variable "base64_internal_ca" {
  description = "Base64 encoded Internal CA certificate"
  type        = string
}