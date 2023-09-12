terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.20.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
  }

  required_version = ">=1"
}

provider "kubernetes" {
  config_path = var.ADMIN_CONF
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
