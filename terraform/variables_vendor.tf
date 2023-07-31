variable "DOCKER_USERNAME" {
  type = string
  sensitive = true
}
variable "DOCKER_PASSWORD" {
  type = string
  sensitive = true
}

variable "RCLONE_FILE" {
  type = string
}

variable "DRONE_GITEA_CLIENT_ID" {
  type = string
  sensitive = true
}
variable "DRONE_GITEA_CLIENT_SECRET" {
  type = string
  sensitive = true
}
variable "DRONE_RPC_SECRET" {
  type = string
  sensitive = true
}
variable "DRONE_TOKEN" {
  type = string
  sensitive = true
}

variable "SMTP_FROM_DOMAIN" {
  type = string
  sensitive = true
}
variable "SMTP_FROM_USER" {
  type = string
  sensitive = true
}
variable "SMTP_HOST" {
  type = string
  sensitive = true
}
variable "SMTP_PASSWORD" {
  type = string
  sensitive = true
}
variable "SMTP_PORT" {
  type = number
  sensitive = true
}
variable "SMTP_USERNAME" {
  type = string
  sensitive = true
}
variable "SMTP_SECURITY" {
  type = string
  sensitive = true
}