# Scenarios:
# - Normal: starting a workspace creates one GPU Pod with persistent home/state
#   and uses the existing games claim, with defaults of 4 CPUs and 8 GiB.
# - Edge: stopping a workspace removes its Pod while retaining its home PVC.
# - Normal: changing CPU and memory updates both resource requests and limits.
# - Normal: the fixed Pod identity matches the chart-managed Service selector,
#   with Sunshine streaming ports and no collision with the gateway's host ports.

mock_provider "coder" {}
mock_provider "kubernetes" {}

override_data {
  target = data.coder_workspace.me
  values = {
    id          = "00000000-0000-0000-0000-000000000001"
    start_count = 1
  }
}

override_data {
  target = data.coder_workspace_owner.me
  values = {
    id = "00000000-0000-0000-0000-000000000002"
  }
}

override_data {
  target = data.coder_parameter.cpu
  values = {
    value = "4"
  }
}

override_data {
  target = data.coder_parameter.memory
  values = {
    value = "8"
  }
}

run "started" {
  command = plan

  # Scenario: start_count=1. Expect one Pod in media, with the NVIDIA allocation
  # and memory/CPU defaults; the assertions compare the planned values.
  assert {
    condition = (
      length(kubernetes_pod_v1.steam) == 1 &&
      kubernetes_pod_v1.steam[0].metadata[0].namespace == "media" &&
      kubernetes_pod_v1.steam[0].spec[0].runtime_class_name == "nvidia" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].limits["nvidia.com/gpu"] == "1" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].requests["cpu"] == "4" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].limits["memory"] == "8Gi"
    )
    error_message = "A started workspace must have one GPU Pod in media with the selected resources."
  }

  # Scenario: custom image startup. Expect the image command to be preserved so
  # systemd can start the agent under the steamheadless account.
  assert {
    condition = (
      kubernetes_pod_v1.steam[0].spec[0].container[0].image == "dockerhub.yusufali.ca/yusufali/steam-headless:latest" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].image_pull_policy == "Always" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].command == null &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].security_context[0].run_as_user == "0"
    )
    error_message = "The mirrored image must retain its root/systemd startup command."
  }

  # Scenario: persistent paths. Expect home and appliance state to use the
  # private home PVC, and games to reference the existing shared media PVC.
  assert {
    condition = (
      kubernetes_persistent_volume_claim_v1.home.spec[0].storage_class_name == "thorin-default" &&
      anytrue([for mount in kubernetes_pod_v1.steam[0].spec[0].container[0].volume_mount : mount.name == "home" && mount.mount_path == "/home/steamheadless" && mount.sub_path == "home"]) &&
      anytrue([for mount in kubernetes_pod_v1.steam[0].spec[0].container[0].volume_mount : mount.name == "home" && mount.mount_path == "/var/lib/steam-headless" && mount.sub_path == "state"]) &&
      anytrue([for volume in kubernetes_pod_v1.steam[0].spec[0].volume : volume.name == "games" && try(volume.persistent_volume_claim[0].claim_name, "") == "media-media"])
    )
    error_message = "Home/state must persist privately and games must use the existing media-media claim."
  }

  # Scenario: Sunshine gateway. Expect the fixed Pod name and label used by the
  # chart-managed Service, with streaming ports and no host-network collision.
  assert {
    condition = (
      kubernetes_pod_v1.steam[0].metadata[0].name == "steamheadless" &&
      kubernetes_pod_v1.steam[0].metadata[0].labels["app.kubernetes.io/name"] == "steamheadless" &&
      toset([for port in kubernetes_pod_v1.steam[0].spec[0].container[0].port : "${port.protocol}/${port.container_port}" if port.name != "web"]) == toset(["TCP/47984", "TCP/47989", "TCP/48010", "UDP/47998", "UDP/47999", "UDP/48000"]) &&
      kubernetes_pod_v1.steam[0].spec[0].host_network == false &&
      alltrue([for port in kubernetes_pod_v1.steam[0].spec[0].container[0].port : port.host_port == null])
    )
    error_message = "The fixed Steam Pod must match the chart-managed Service and expose Sunshine without using host ports."
  }
}

run "stopped" {
  command = plan

  override_data {
    target = data.coder_workspace.me
    values = {
      id          = "00000000-0000-0000-0000-000000000001"
      start_count = 0
    }
  }

  # Scenario: start_count=0. Expect no Pod and the same home PVC identity as the
  # started plan, so a stop/start does not replace persistent workspace data.
  assert {
    condition = (
      length(kubernetes_pod_v1.steam) == 0 &&
      kubernetes_persistent_volume_claim_v1.home.metadata[0].name == "steam-00000000-0000-0000-0000-000000000001-home"
    )
    error_message = "Stopping a workspace must retain its stable home PVC and remove its Pod."
  }
}

run "resized" {
  command = plan

  override_data {
    target = data.coder_parameter.cpu
    values = {
      value = "6"
    }
  }

  override_data {
    target = data.coder_parameter.memory
    values = {
      value = "16"
    }
  }

  # Scenario: CPU=6, memory=16. Expect matching requests and limits of 6 CPUs
  # and 16 GiB, while the GPU allocation remains fixed at one.
  assert {
    condition = (
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].requests["cpu"] == "6" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].limits["cpu"] == "6" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].requests["memory"] == "16Gi" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].limits["memory"] == "16Gi" &&
      kubernetes_pod_v1.steam[0].spec[0].container[0].resources[0].limits["nvidia.com/gpu"] == "1"
    )
    error_message = "CPU and memory changes must update requests and limits without changing the GPU allocation."
  }
}
