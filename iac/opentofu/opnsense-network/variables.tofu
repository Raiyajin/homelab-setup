variable "default_tags" {
  description = "VM Template tags"
  type        = list(string)
  default     = ["opnsense"]
}


variable "opnsense_template_id" {
  description = "Id of the OPNsense template VM"
  type        = string
}

variable "opnsense_version" {
  description = "Version of the OPNsense ISO"
  type        = string
}

variable "proxmox_node" {
  description = "Node to create the template into"
  type        = string
}