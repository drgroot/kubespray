# make account for apps. readonly
resource "random_password" "readonly_external_password" {
  length  = 30
  special = true
}
resource "vault_policy" "readonly_access_secrets" {
  name = "kubernetes-readonly"
  policy = <<-EOT
  %{ for pathname in ["external-infra/data/*","kubernetes/data/*"] ~}
  path "${pathname}" {
    capabilities = ["read","list"]
  }
  %{ endfor ~}
  EOT 
}
resource "vault_generic_endpoint" "readonly_access_secrets" {
  path  = "auth/userpass/users/kubernetesreadonly"
  ignore_absent_fields = true
  data_json = jsonencode({
    policies = [vault_policy.readonly_access_secrets.name]
    password = random_password.readonly_external_password.result
  })
}

resource "kubernetes_secret" "vault_password" {
  metadata {
    name = "vault-password"
    namespace = "default"
  }
  
  data = {
    password = random_password.readonly_external_password.result
  }
}
