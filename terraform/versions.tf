locals {
  versions = {
    gitlab = {
      name   = "gitlab/gitlab-ee"
      tag    = "16.4.1"
    }
    coder = {
      name   = "ghcr.io/coder/coder"
      tag    = "v2.3.0"
    }
    registry = {
      name = "registry"
      tag = "2.8.3"
    }

    databases={
      postgres = "13.6"
      # mysql = "5.7.38"
      mariadb = "10.7.3"
    }

    externalsecrets = "0.9.6"
    ingress    = "4.7.3"
    keda       = "2.12.0"
    certmanager = "v1.13.1"
    nfs_provisioner = "4.0.18"
    externaldns = "1.13.1"
    prometheus = "51.7.0"

    gitlabrunner = "v0.57.1" # https://gitlab.com/gitlab-org/charts/gitlab-runner/-/tags
    redis = "9.0.12"         # https://github.com/bitnami/charts/blob/main/bitnami/redis-cluster/Chart.yaml
  }
}
