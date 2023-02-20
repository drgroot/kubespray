terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.6.0"
    }

    drone = {
      source  = "Lucretius/drone"
      version = "0.2.5"
    }
  }

  required_version = ">=1"
}

provider "vault" {
  skip_child_token = true
  address = var.VAULT_ADDRESS
  auth_login {
    path = "auth/userpass/login/${var.VAULT_USERNAME}"

    parameters = {
      password = var.VAULT_PASSWORD
    }
  }
}

data "vault_generic_secret" "drone" {
  path = "external-infra/DRONE"
}

provider "drone" {
  server = "https://drone.${var.DOMAIN_NAME}"
  token = data.vault_generic_secret.drone.data.DRONE_TOKEN
}