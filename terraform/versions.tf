locals {
  versions = {
    gitlab = {
      name   = "gitlab/gitlab-ee"
      tag    = "16.3.0"
      semvar = "~16.3"
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
    gitlabrunner = "v0.56.0"
    externaldns = "1.13.1"
  }
}
