variable "VAULT_ADDRESS" {
  type = string
  sensitive = true
}

variable "VAULT_USERNAME" {
  type = string
  sensitive = true
}

variable "VAULT_PASSWORD" {
  type = string
  sensitive = true
}

variable "ADMIN_CONF" {
  type = string
}

variable "STORAGE_HOSTNAME" {
  type = string
  sensitive = true
}

variable "STORAGE_MOUNT" {
  type = string
  sensitive = true
}

variable "STORAGE_DOWNLOADS" {
  type = string
  sensitive = true
}

variable "STORAGE_MEDIA" {
  type = string
  sensitive = true
}
