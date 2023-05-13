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
    verdaccio = {
      name   = "verdaccio/verdaccio"
      tag    = "5.15.4"
      semvar = "~5"
    }

    databases={
      postgres = "13.6"
      mysql = "5.7.38"
      mariadb = "10.7.3"
    }

    ingress    = "4.0.6"
    keda       = "2.10.1"
    longhorn   = "1.4.2"
    nfs_provisioner = "4.0.18"
  }
}
