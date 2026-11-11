terraform {
  required_version = ">= 1.7.0"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = "2.20.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
  }
}

provider "coder" {}

# Coder's provisioner uses its in-cluster service account.
provider "kubernetes" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU request (cores)"
  description  = "CPU request. Set to 0 to omit."
  type         = "number"
  default      = "4"
  mutable      = true
  order        = 1

  validation {
    min = 0
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory request (GiB)"
  description  = "Memory request. Set to 0 to omit."
  type         = "number"
  default      = "8"
  mutable      = true
  order        = 3

  validation {
    min = 0
  }
}

data "coder_parameter" "cpu_limit" {
  name         = "cpu_limit"
  display_name = "CPU limit (cores)"
  description  = "Set to 0 to omit the limit. Otherwise, must be at least the corresponding request."
  type         = "number"
  default      = "4"
  mutable      = true
  order        = 2

  validation {
    min = 0
  }

  lifecycle {
    postcondition {
      condition     = tonumber(self.value) == 0 || tonumber(data.coder_parameter.cpu.value) <= tonumber(self.value)
      error_message = "CPU request cannot exceed its limit unless the limit is 0 (omitted)."
    }
  }
}

data "coder_parameter" "memory_limit" {
  name         = "memory_limit"
  display_name = "Memory limit (GiB)"
  description  = "Set to 0 to omit the limit. Otherwise, must be at least the corresponding request."
  type         = "number"
  default      = "8"
  mutable      = true
  order        = 4

  validation {
    min = 0
  }

  lifecycle {
    postcondition {
      condition     = tonumber(self.value) == 0 || tonumber(data.coder_parameter.memory.value) <= tonumber(self.value)
      error_message = "Memory request cannot exceed its limit unless the limit is 0 (omitted)."
    }
  }
}

data "coder_parameter" "iscsi" {
  name         = "iscsi"
  display_name = "Home iSCSI volume"
  description  = "Portal;target IQN;LUN. Defaults to the 1024 GiB Steam LUN on Thorin."
  type         = "string"
  default      = "192.168.1.3:3260;iqn.2026-01.com.middleearth:thorin;3"
  mutable      = true
  order        = 5

  validation {
    regex = "^[^;[:space:]]+;iqn\\.[^;[:space:]]+;[0-9]+$"
    error = "Enter portal;target IQN;LUN, for example 192.168.1.3:3260;iqn.2026-01.com.middleearth:thorin;3."
  }
}

data "coder_parameter" "steamapps_iscsi" {
  name         = "steamapps_iscsi"
  display_name = "Steam library iSCSI volume"
  description  = "Portal;target IQN;LUN. Defaults to the 5 TiB Steam games LUN on Thorin."
  type         = "string"
  default      = "192.168.1.3:3260;iqn.2026-01.com.middleearth:thorin;5"
  mutable      = true
  order        = 6

  validation {
    regex = "^[^;[:space:]]+;iqn\\.[^;[:space:]]+;[0-9]+$"
    error = "Enter portal;target IQN;LUN, for example 192.168.1.3:3260;iqn.2026-01.com.middleearth:thorin;5."
  }
}

data "coder_parameter" "steamapps_mount_path" {
  name         = "steamapps_mount_path"
  display_name = "Steam library mount path"
  description  = "Absolute path inside the workspace. The default is ~/.local/share/Steam/steamapps for steamheadless."
  type         = "string"
  default      = "/home/steamheadless/.local/share/Steam/steamapps"
  mutable      = true
  order        = 7

  validation {
    regex = "^/[^[:space:]]+$"
    error = "Enter an absolute directory path, for example /home/steamheadless/.local/share/Steam/steamapps."
  }
}

locals {
  home_iscsi      = split(";", data.coder_parameter.iscsi.value)
  steamapps_iscsi = split(";", data.coder_parameter.steamapps_iscsi.value)
  namespace       = "media"
  image           = "dockerhub.yusufali.ca/yusufali/steam-headless:latest"
  sunshine_ports = {
    https   = { port = 47984, protocol = "TCP" }
    http    = { port = 47989, protocol = "TCP" }
    rtsp    = { port = 48010, protocol = "TCP" }
    video   = { port = 47998, protocol = "UDP" }
    control = { port = 47999, protocol = "UDP" }
    audio   = { port = 48000, protocol = "UDP" }
  }
  labels = {
    "app.kubernetes.io/name"       = "steamheadless"
    "app.kubernetes.io/managed-by" = "coder"
    "coder.workspace.id"           = data.coder_workspace.me.id
    "coder.owner.id"               = data.coder_workspace_owner.me.id
  }
}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  # The image's systemd service runs the agent as steamheadless with its HOME.
  # Leave dir unset so terminals and editors follow that account's home.
}

resource "coder_app" "steam" {
  agent_id     = coder_agent.main.id
  slug         = "steam"
  display_name = "Steam"
  url          = "https://localhost:8483"
  subdomain    = true
  share        = "owner"
}

data "kubernetes_persistent_volume_claim_v1" "games" {
  metadata {
    name      = "media-games"
    namespace = local.namespace
  }
}

resource "kubernetes_pod_v1" "steam" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "steamheadless"
    namespace = local.namespace
    labels    = local.labels
  }

  spec {
    # Envoy owns the public streaming ports; Sunshine listens on the Pod network.
    host_network                     = false
    dns_policy                       = "ClusterFirst"
    runtime_class_name               = "nvidia"
    automount_service_account_token  = false
    restart_policy                   = "Always"
    termination_grace_period_seconds = 60

    image_pull_secrets {
      name = "cluster-docker-secrets"
    }

    init_container {
      name              = "prepare-storage"
      image             = "dockerhub.yusufali.ca/library/alpine:3.24"
      image_pull_policy = "Always"
      command = ["/bin/sh", "-ec", <<-EOT
        mkdir -p /workspace/home/.local/share/Steam /workspace/state /shared/games
        chown 1000:1000 /workspace/home /workspace/home/.local /workspace/home/.local/share /workspace/home/.local/share/Steam /shared/games /steamapps
        chmod 0755 /workspace/home /shared/games /steamapps
        chown 0:0 /workspace/state
        chmod 0700 /workspace/state
        chmod 1777 /tmp /dev/shm
      EOT
      ]

      security_context {
        run_as_user = 0
      }

      volume_mount {
        name       = "home"
        mount_path = "/workspace"
      }
      volume_mount {
        name       = "games"
        mount_path = "/shared"
      }
      volume_mount {
        name       = "steamapps"
        mount_path = "/steamapps"
      }
      volume_mount {
        name       = "tmp"
        mount_path = "/tmp"
      }
      volume_mount {
        name       = "shm"
        mount_path = "/dev/shm"
      }
    }

    container {
      name              = "steam-headless"
      image             = local.image
      image_pull_policy = "Always"

      # Keep the image's startup command: it initializes the desktop and
      # launches the Coder agent through coder-agent.service as steamheadless.
      security_context {
        run_as_user = 0
        privileged  = true
      }

      resources {
        requests = merge(
          { "nvidia.com/gpu" = "1" },
          tonumber(data.coder_parameter.cpu.value) == 0 ? {} : { cpu = data.coder_parameter.cpu.value },
          tonumber(data.coder_parameter.memory.value) == 0 ? {} : { memory = "${data.coder_parameter.memory.value}Gi" },
        )
        limits = merge(
          { "nvidia.com/gpu" = "1" },
          tonumber(data.coder_parameter.cpu_limit.value) == 0 ? {} : { cpu = data.coder_parameter.cpu_limit.value },
          tonumber(data.coder_parameter.memory_limit.value) == 0 ? {} : { memory = "${data.coder_parameter.memory_limit.value}Gi" },
        )
      }

      env {
        name  = "CODER_AGENT_INIT_SCRIPT"
        value = coder_agent.main.init_script
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      env {
        name  = "PUID"
        value = "1000"
      }
      env {
        name  = "PGID"
        value = "1000"
      }
      env {
        name  = "TZ"
        value = "America/Toronto"
      }
      env {
        name  = "NVIDIA_DRIVER_CAPABILITIES"
        value = "all"
      }
      port {
        name           = "web"
        container_port = 8483
        protocol       = "TCP"
      }

      dynamic "port" {
        for_each = local.sunshine_ports
        content {
          name           = "sun-${port.key}"
          container_port = port.value.port
          protocol       = port.value.protocol
        }
      }

      readiness_probe {
        tcp_socket {
          port = "web"
        }
        initial_delay_seconds = 10
        period_seconds        = 5
      }

      volume_mount {
        name       = "home"
        mount_path = "/home/steamheadless"
        sub_path   = "home"
      }
      volume_mount {
        name       = "home"
        mount_path = "/var/lib/steam-headless"
        sub_path   = "state"
      }
      volume_mount {
        name       = "games"
        mount_path = "/mnt/games"
        sub_path   = "games"
      }
      volume_mount {
        name       = "steamapps"
        mount_path = data.coder_parameter.steamapps_mount_path.value
      }
      volume_mount {
        name       = "shm"
        mount_path = "/dev/shm"
      }
      volume_mount {
        name       = "run"
        mount_path = "/run"
      }
      volume_mount {
        name       = "tmp"
        mount_path = "/tmp"
      }
      volume_mount {
        name       = "input"
        mount_path = "/dev/input"
      }
      volume_mount {
        name       = "uinput"
        mount_path = "/dev/uinput"
      }
      volume_mount {
        name       = "udev"
        mount_path = "/run/udev"
      }
    }

    volume {
      name = "home"
      iscsi {
        target_portal = local.home_iscsi[0]
        iqn           = local.home_iscsi[1]
        lun           = tonumber(local.home_iscsi[2])
        fs_type       = "ext4"
        read_only     = false
      }
    }
    volume {
      name = "steamapps"
      iscsi {
        target_portal = local.steamapps_iscsi[0]
        iqn           = local.steamapps_iscsi[1]
        lun           = tonumber(local.steamapps_iscsi[2])
        fs_type       = "ext4"
        read_only     = false
      }
    }
    volume {
      name = "games"
      persistent_volume_claim {
        claim_name = data.kubernetes_persistent_volume_claim_v1.games.metadata[0].name
      }
    }
    volume {
      name = "shm"
      empty_dir {
        medium     = "Memory"
        size_limit = "2Gi"
      }
    }
    volume {
      name = "run"
      empty_dir {
        medium = "Memory"
      }
    }
    volume {
      name = "tmp"
      empty_dir {}
    }
    volume {
      name = "input"
      # shinputd discovers virtual devices into the container's private input tree.
      empty_dir {}
    }
    volume {
      name = "uinput"
      host_path {
        path = "/dev/uinput"
        type = "CharDevice"
      }
    }
    volume {
      name = "udev"
      # The input daemon writes its own udev database before starting KWin.
      empty_dir {
        medium = "Memory"
      }
    }
  }
}

