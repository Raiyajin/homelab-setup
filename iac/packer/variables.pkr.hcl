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