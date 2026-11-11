ARG DRIVER_VERSION=580.126.09
FROM nvcr.io/nvidia/driver:${DRIVER_VERSION}-ubuntu24.04 AS driver

# Keep the GPU Operator's driver install, upgrade, and unload lifecycle while
# including DRM/KMS for Wayland desktops alongside CUDA/NVENC workloads.
COPY --chmod=755 enable-drm /usr/local/bin/enable-nvidia-drm
RUN /usr/local/bin/enable-nvidia-drm

# Compile-check the open DRM module without loading anything into the host.
FROM driver AS kernel-check
ARG KERNEL_VERSION=6.8.0-147-generic
RUN apt-get update \
    && apt-get install -y --no-install-recommends "linux-headers-${KERNEL_VERSION}" \
    && sh "/drivers/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run" \
        --extract-only --target /tmp/nvidia-source \
    && make -C /tmp/nvidia-source/kernel-open -j2 \
        SYSSRC="/usr/src/linux-headers-${KERNEL_VERSION}" \
        SYSOUT="/usr/src/linux-headers-${KERNEL_VERSION}" \
    && test -s /tmp/nvidia-source/kernel-open/nvidia-drm.ko

FROM driver AS runtime
