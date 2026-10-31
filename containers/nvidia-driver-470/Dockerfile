# R470 was never published for Ubuntu 24.04 by NVIDIA. Build for the Operator's
# required <driver-version>-<node-os> tag before enabling the legacy driver CR:
# docker build -t yusufservc/nvidia-driver:470.256.02-ubuntu24.04 .
# docker push yusufservc/nvidia-driver:470.256.02-ubuntu24.04
FROM ubuntu:24.04 AS driver

ARG DRIVER_VERSION=470.256.02
# NVIDIA GPU Driver Container release 25.01.21 (Apache-2.0).
ARG DRIVER_CONTAINER_COMMIT=fe65aa7c08d1295134607be5cb46c63988da380a
ENV DEBIAN_FRONTEND=noninteractive \
    DRIVER_VERSION=${DRIVER_VERSION} \
    DRIVER_TYPE=passthrough \
    DRIVER_BRANCH=470 \
    TARGETARCH=amd64 \
    NVIDIA_VISIBLE_DEVICES=void \
    KERNEL_MODULE_TYPE=proprietary

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl kmod file libelf-dev libglvnd-dev \
      pkg-config && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://raw.githubusercontent.com/NVIDIA/gpu-driver-container/${DRIVER_CONTAINER_COMMIT}/ubuntu24.04/nvidia-driver" \
      -o /usr/local/bin/nvidia-driver && \
    chmod 0755 /usr/local/bin/nvidia-driver && \
    # Kernel packages may extract under lib or usr/lib. R470 has only
    # proprietary modules and its installer predates the -m option.
    sed -i \
      -e '/    mv lib\/modules.*modules\.\*/i\    local module_root=lib; [ -d lib/modules/${KERNEL_VERSION} ] || module_root=usr/lib' \
      -e 's|mv lib/modules/|mv ${module_root}/modules/|g' \
      -e '/install_args+=("-m=/d' /usr/local/bin/nvidia-driver

WORKDIR /drivers
RUN curl -fsSL "https://download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run" \
      -o "NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run" && \
    chmod 0755 "NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run"

ENTRYPOINT ["nvidia-driver", "init"]

# Optional build-only check; compiles modules without touching the host driver:
# docker build --target kernel-check --build-arg KERNEL_VERSION=6.8.0-147-generic .
FROM driver AS kernel-check
ARG KERNEL_VERSION=6.8.0-147-generic
RUN apt-get update && apt-get install -y --no-install-recommends "linux-headers-${KERNEL_VERSION}" && \
    sh "NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run" --extract-only --target /tmp/nvidia-source && \
    make -C /tmp/nvidia-source/kernel -j2 SYSSRC="/usr/src/linux-headers-${KERNEL_VERSION}" \
      SYSOUT="/usr/src/linux-headers-${KERNEL_VERSION}" && \
    test -s /tmp/nvidia-source/kernel/nvidia.ko

FROM driver AS runtime
