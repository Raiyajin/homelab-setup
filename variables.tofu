variable "proxmox_host" {
    description = "Proxmox Host"
    type = string
}

variable "proxmox_api_token" {
    description = "Proxmox API credentials, should be in the format '<USER>@<REALM>!<TOKENID>=<UUID>'"
    type = string
}