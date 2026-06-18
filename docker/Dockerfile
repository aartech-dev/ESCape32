# ESCape32 firmware build environment
#
# This image only contains the TOOLCHAIN (cmake, arm-none-eabi-gcc/binutils/newlib,
# and a prebuilt libopencm3). It does NOT contain any firmware source.
#
# You mount your own fork (with your own top-level Makefile / CMake invocations for
# the various Remora targets) into /workspace at `docker run` time. That way this
# image stays valid across branches, versions, and forks — rebuild it only when you
# want to bump the toolchain or the libopencm3 pin, not every time firmware source changes.
#
# Build the image:
#   docker build -t aart/escape32-builder .
#
# Use it against your checked-out fork:
#   docker run --rm -v "$(pwd):/workspace" aart/escape32-builder make
#
# Drop into a shell for interactive work:
#   docker run --rm -it -v "$(pwd):/workspace" aart/escape32-builder bash

FROM ubuntu:24.04

# Pin libopencm3 to a known-good commit for reproducible builds.
# Verified against this commit while testing this Dockerfile (2026-06-18).
# Bump with --build-arg LIBOPENCM3_REF=<commit-or-tag> when you want newer libopencm3.
ARG LIBOPENCM3_REF=76670e09e0b379e003227a76b98bc3bae4386a13

# Targets libopencm3 builds support files for. Covers every MCU family currently
# used across upstream ESCape32 targets (F0/AT32/GD32 clones -> stm32/f0,
# G071 -> stm32/g0, G431 -> stm32/g4, L431 -> stm32/l4). Extend this if a future
# Remora revision lands on a different STM32 family.
ARG LIBOPENCM3_TARGETS="stm32/f0 stm32/g0 stm32/g4 stm32/l4"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        gcc-arm-none-eabi \
        binutils-arm-none-eabi \
        libnewlib-arm-none-eabi \
        make \
        git \
        ca-certificates \
        stlink-tools \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# Build libopencm3 once at image-build time so container startup is instant.
RUN git clone https://github.com/libopencm3/libopencm3.git /opt/libopencm3 \
    && cd /opt/libopencm3 \
    && git checkout "${LIBOPENCM3_REF}" \
    && make TARGETS="${LIBOPENCM3_TARGETS}" \
    && rm -rf /opt/libopencm3/.git

ENV LIBOPENCM3_DIR=/opt/libopencm3

WORKDIR /workspace

CMD ["bash"]
