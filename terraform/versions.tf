locals {
  versions = {
    gitea = {
      name   = "gitea/gitea"
      semvar = "~1.x.x"
      tag    = "1.18"
    }
    drone = {
      name   = "drone/drone"
      tag    = "2.12.0"
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
  }
}
