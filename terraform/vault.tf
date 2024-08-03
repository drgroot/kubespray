# make account for apps. readonly
resource "random_password" "readonly_external_password" {
  for_each = local.tenant_map

  length  = 30
  special = true
}

resource "vault_policy" "readonly_access_secrets" {
  for_each = local.tenant_map

  name = "kubernetes-readonly-${each.key}"

  policy = <<-EOT
  path "kubernetes/data/${each.key}*" {
    capabilities = ["read","list"]
  }

  %{ for flag in [for x in each.value.flags: split(":",x)[0] if strcontains(x, ":")] ~}
  path "kubernetes/data/${flag}" {
    capabilities = ["read","list"]
  }
  path "kubernetes/data/${flag}/*" {
    capabilities = ["read","list"]
  }
  %{ endfor ~}

  %{ for flag in [for x in each.value.flags: x if !strcontains(x, ":")] ~}
  path "external-infra/data/${flag}" {
    capabilities = ["read","list"]
  }
  path "external-infra/data/${flag}/*" {
    capabilities = ["read","list"]
  }
  %{ endfor ~}
  EOT 
}
resource "vault_generic_endpoint" "readonly_access_secrets" {
  for_each = local.tenant_map

  path  = "auth/userpass/users/kubernetesreadonly${each.key}"
  ignore_absent_fields = true
  data_json = jsonencode({
    policies = [vault_policy.readonly_access_secrets[each.key].name]
    password = random_password.readonly_external_password[each.key].result
  })
}

resource "kubernetes_namespace" "tenant" {
  for_each = { for tenant in local.tenants : tenant.namespace => tenant if contains(keys(tenant), "repository") }

  metadata {
    name = each.value.namespace
    labels = {
      type = "tenant"
      dockerpublic  = contains(each.value.flags, "DOCKER_PUBLIC")  ? "okay" : "false"
      dockerprivate = contains(each.value.flags, "DOCKER_PRIVATE") ? "okay" : "false"
    }
  }
}

resource "kubernetes_secret" "vault_password_tenant" {
  for_each = local.tenant_map

  metadata {
    name = "vault-password"
    namespace = each.value.namespace
  }

  data = {
    password = random_password.readonly_external_password[each.key].result
  }
}

resource "kubernetes_secret" "vault_password_cluster" {
  metadata {
    name = "vault-password-readwrite"
    namespace = "default"
  }
  
  data = {
    password = var.VAULT_PASSWORD
  }
}
