locals {
  versions = {
    gitlab = {
      name   = "gitlab/gitlab-ee"
      tag    = "16.4.1"
      semvar = "~16.x.x"
    }
    coder = {
      name   = "ghcr.io/coder/coder"
      tag    = "v2.2.1"
      semvar = "~v2.x.x"
    }
    registry = {
      name = "registry"
      tag = "2.8.3"
      semvar = "~2"
    }

    databases={
      postgres = "13.6"
      # mysql = "5.7.38"
      mariadb = "10.7.3"
    }

    externalsecrets = "0.9.4"
    ingress    = "4.0.6"
    keda       = "2.10.1"
    certmanager = "v1.12.3"
    nfs_provisioner = "4.0.18"
    gitlabrunner = "v0.57.1"
    externaldns = "1.13.1"
  }
}
