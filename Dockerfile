FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        bc \
        bison \
        bzip2 \
        ca-certificates \
        ccache \
        findutils \
        flex \
        gcc \
        git \
        libc6-dev \
        libfdt-dev \
        libffi-dev \
        libglib2.0-dev \
        libpixman-1-dev \
        locales \
        make \
        meson \
        ninja-build \
        pkgconf \
        python3 \
        python3-venv \
        sed \
        tar \
        libtpms-dev && \
    rm -rf /var/lib/apt/lists/*

COPY qemu-sbsa-patch.patch /tmp/qemu-sbsa-patch.patch

ARG QEMU_URL="https://gitlab.com/qemu-project/qemu.git"
ARG QEMU_BRANCH="v10.0.0"
ARG TARGETARCH

RUN --mount=type=cache,id=ccache-${TARGETARCH},target=/root/.cache/ccache \
    git clone "${QEMU_URL}" --branch "${QEMU_BRANCH}" --depth 1 qemu && \
    cd qemu && \
    git apply /tmp/qemu-sbsa-patch.patch && \
    PATH="/usr/lib/ccache:${PATH}" ./configure --target-list=aarch64-softmmu --enable-plugins --enable-tpm && \
    PATH="/usr/lib/ccache:${PATH}" ninja -C build qemu-system-aarch64 && \
    ninja -C build install && \
    cd .. && \
    rm -rf qemu
