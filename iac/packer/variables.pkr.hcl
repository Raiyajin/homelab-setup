variable "default_tags" {
  description = "VM Template tags"
  type        = string
  default     = "opnsense;template"
}

variable "opnsense_version" {
  description = "Version of the OPNsense ISO"
  type        = string
}

variable "proxmox_node" {
  description = "Node to create the template into"
  type        = string
}

variable "wg_privkey" {
  type      = string
  sensitive = true
  default   = ""
}

variable "wg_pubkey" {
  type    = string
  default = ""
}

variable "wg_client_pubkey" {
  type    = string
  default = ""
}

variable "opnsense_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "opnsense_api_secret" {
  type      = string
  sensitive = true
  default   = ""
}