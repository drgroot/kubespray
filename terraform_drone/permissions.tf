data "vault_generic_secret" "NPM" {
  path = "kubernetes/NPM"
}

data "vault_generic_secret" "DOCKER" {
  path = "kubernetes/DOCKER"
}

locals {
  allow_on_pull_request = ["DOCKERCONFIG", "NPM_PASSWORD"]
  permissions = flatten([
    for x in jsondecode(data.vault_generic_secret.tenants.data.permissions) : flatten([
      for flag in x.flags: flatten([
        flag == "docker:private" ? [
          {
            key = "DOCKERCONFIG",
            value = data.vault_generic_secret.DOCKER.data[".dockerconfigjson"]
            name = contains(keys(x),"repository") ? x.repository :x.organization
            type = contains(keys(x),"repository") ? "repository" : "organization"
          },
          {
            key = "PRIVATE_REGISTRY_URL", 
            value = data.vault_generic_secret.DOCKER.data["PRIVATE_REGISTRY_URL"]
            name = contains(keys(x),"repository") ? x.repository :x.organization
            type = contains(keys(x),"repository") ? "repository" : "organization"
          },
        ]: [],
        flag == "docker:public" ? [
          {
            key = "DOCKERCONFIG",
            value = data.vault_generic_secret.DOCKER.data[".dockerconfigjson"]
            name = contains(keys(x),"repository") ? x.repository :x.organization
            type = contains(keys(x),"repository") ? "repository" : "organization"
          },
          {
            key = "PUBLIC_REGISTRY_URL",
            value = data.vault_generic_secret.DOCKER.data["PUBLIC_REGISTRY_URL"]
            name = contains(keys(x),"repository") ? x.repository :x.organization
            type = contains(keys(x),"repository") ? "repository" : "organization"
          },
        ]: [],
        flag == "docker" ? [
          {
            key = "DOCKERCONFIG",
            value = data.vault_generic_secret.DOCKER.data[".dockerconfigjson"]
            name = contains(keys(x),"repository") ? x.repository :x.organization
            type = contains(keys(x),"repository") ? "repository" : "organization"
          },
          {
            key = "PUBLIC_REGISTRY_URL",
            value = data.vault_generic_secret.DOCKER.data["PUBLIC_REGISTRY_URL"]
            name = contains(keys(x),"repository") ? x.repository :x.organization
            type = contains(keys(x),"repository") ? "repository" : "organization"
          },
          {
            key = "PRIVATE_REGISTRY_URL",
            value = data.vault_generic_secret.DOCKER.data["PRIVATE_REGISTRY_URL"]
            name = contains(keys(x),"repository") ? x.repository :x.organization
            type = contains(keys(x),"repository") ? "repository" : "organization"
          },
        ]: [],
        # flag == "npm" ? [
        #   {
        #     key = "NPM_HOST",
        #     value = data.vault_generic_secret.NPM.data["NPM_HOST"]
        #     name = contains(keys(x),"repository") ? x.repository :x.organization
        #     type = contains(keys(x),"repository") ? "repository" : "organization"
        #   },
        #   {
        #     key = "NPM_PASSWORD",
        #     value = data.vault_generic_secret.NPM.data["NPM_TOKEN"]
        #     name = contains(keys(x),"repository") ? x.repository :x.organization
        #     type = contains(keys(x),"repository") ? "repository" : "organization"
        #   },
        #   {
        #     key = "NPM_USERNAME",
        #     value = data.vault_generic_secret.NPM.data["username"]
        #     name = contains(keys(x),"repository") ? x.repository :x.organization
        #     type = contains(keys(x),"repository") ? "repository" : "organization"
        #   },
        # ]: [],
      ])
    ])
  ])

  repository_secret = [for x in local.permissions: x if x.type == "repository"]
  organization_secret = [for x in local.permissions: x if x.type == "organization"]
}

resource "drone_secret" "repo_secret" {
  count = length(local.repository_secret)
  repository            = local.repository_secret[count.index].name
  name                  = local.repository_secret[count.index].key
  value                 =local.repository_secret[count.index].value
  allow_on_pull_request = (!contains(local.allow_on_pull_request,local.repository_secret[count.index].key))
}

resource "drone_orgsecret" "org_secret" {
  count = length(local.organization_secret)
  namespace            = local.organization_secret[count.index].name
  name                  = local.organization_secret[count.index].key
  value                 =local.organization_secret[count.index].value
  allow_on_pull_request = (!contains(local.allow_on_pull_request,local.organization_secret[count.index].key))
}