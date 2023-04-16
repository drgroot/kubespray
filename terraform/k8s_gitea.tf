resource "kubernetes_secret" "gitea" {
  metadata {
    name      = "gitea"
    namespace = "default"
  }

  data = {
    GITEA__database__DB_TYPE = "postgres"
    GITEA__database__HOST    = "${kubernetes_service_v1.database["postgres"].metadata[0].name}.default.cluster.local:${kubernetes_service_v1.database["postgres"].spec[0].port[0].port}"
    GITEA__database__NAME    = "gitea"
    GITEA__database__USER    = random_string.database_username.result
    GITEA__database__PASSWD  = random_password.database_password.result

    GITEA__service__DISABLE_REGISTRATION    = "true"
    GITEA__service__DEFAULT_USER_VISIBILITY = "limited"
    GITEA__service__DEFAULT_ORG_VISIBILITY  = "limited"

    GITEA__server__DOMAIN     = join(".",["git",data.cloudflare_zones.domain.zones[0].name])
    GITEA__server__ROOT_URL   = "https://${join(".",["git",data.cloudflare_zones.domain.zones[0].name])}"
    GITEA__server__SSH_DOMAIN = "bootstrap-tools-gitea.default.svc.cluster.local"

    GITEA__repository__DISABLED_REPO_UNITS = "repo.issues,repo.ext_issues,repo.wiki, repo.ext_wiki,repo.projects"
    GITEA__repository__DEFAULT_REPO_UNITS  = "repo.code,repo.releases,repo.pulls"
    GITEA__repository__DISABLE_STARS       = "true"
    GITEA__repository__DEFAULT_BRANCH      = "master"

    GITEA__ui__DEFAULT_THEME = "gitea"
  }
}
