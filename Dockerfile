FROM ubuntu:24.04

ARG QEMU_URL="https://gitlab.com/qemu-project/qemu.git"
ARG QEMU_BRANCH="v10.0.0"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        bc \
        bison \
        bzip2 \
        ca-certificates \
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
        git && \
    git clone "${QEMU_URL}" --branch "${QEMU_BRANCH}" --depth 1 qemu && \
    cd qemu && \
    ./configure --target-list=aarch64-softmmu && \
    ninja -C build qemu-system-aarch64 && \
    ninja -C build install && \
    cd .. && \
    rm -rf qemu && \
    rm -rf /var/lib/apt/lists/*
