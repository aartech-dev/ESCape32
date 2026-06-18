# ESCape32 firmware build environment

A pinned, reproducible Docker build environment for [ESCape32](https://github.com/neoxic/ESCape32)
(and forks of it, e.g. an AART/Remora fork). The image carries the toolchain only —
`cmake`, `arm-none-eabi-gcc`/`binutils`/`newlib`, and a prebuilt `libopencm3` — so it
stays valid across branches and firmware versions. Your firmware source (and your own
top-level Makefile driving the different Remora target builds) is mounted in at
container-run time, not baked into the image.

**Validated so far:** image builds and runs on an Apple Silicon Mac; a full
firmware build (`cmake -B build` + `make -C build`, mounted source, output
owned by the calling user) completes against the real ESCape32 source. Not
yet exercised: the GitHub Actions side (`build-image.yml` / `release.yml`)
and `Dockerfile.arch`.

## Why mount instead of `COPY`

If the source were `COPY`'d into the image, you'd rebuild the entire image (re-cloning
and rebuilding libopencm3) every time you changed a line of firmware code. Mounting
means: build the image once, then every `docker run` against your checked-out fork
takes seconds.

## What's pinned, and why it matters

`libopencm3` is checked out to a fixed commit (set via the `LIBOPENCM3_REF` build arg)
rather than always pulling `master`, so two people — or two CI runs six months
apart — building the same firmware source produce bit-identical output.

The compiler matters too: while testing this image I found that a handful of upstream
ESCape32's flash-constrained legacy targets (the STM32F051-based ones) overflow ROM by
a couple hundred bytes under Ubuntu 24.04's stock `gcc-arm-none-eabi` (13.2.1), where
they apparently fit under whatever compiler upstream's GitHub Actions runner happens to
have. Your `AART1` target builds cleanly either way, but it's worth actually flashing
and bench-testing a build from this image before treating it as equivalent to a build
from a different toolchain — code size right at the edge of flash is exactly where
compiler version differences bite.

## Usage

Build the image once:
```bash
docker build -t aart/escape32-builder .
```

Then, from inside your actual firmware checkout (the directory with
`CMakeLists.txt`, `src/`, `mcu/`, `boot/` at its root — not this tooling
folder):

```bash
cd ~/code/ESCape32-aart

# First time, or whenever CMakeLists.txt changes:
docker run --rm -v "$(pwd):/workspace" --user 501:20 aart/escape32-builder \
  bash -c "cmake -B build -D LIBOPENCM3_DIR=\$LIBOPENCM3_DIR && make -C build"

# Every rebuild after that (editing src/*.c etc.), faster, no reconfigure:
docker run --rm -v "$(pwd):/workspace" --user 501:20 aart/escape32-builder \
  make -C build
```

Replace `501:20` with your own `uid:gid` if different (`id -u` / `id -g` on
macOS, or `$(id -u):$(id -g)` substituted directly into the command — that
substitution didn't work reliably in testing for reasons we didn't fully
pin down, so using the literal numbers is the version actually confirmed
working). Either way, this is what makes `build/` — and every `.elf`/`.hex`/
`.bin` in it — come out owned by you on the host instead of root.

ESCape32 itself is CMake-based; there's no plain `Makefile` at the repo
root, only inside `build/` after `cmake -B build` generates one. So a bare
`make` run from the repo root (rather than `make -C build`, or `cd build &&
make`) will fail with "No targets specified and no makefile found" — that's
expected, not a sign anything's broken. If you write your own top-level
Makefile to drive the different Remora target configs, it'd wrap exactly
this `cmake -B build && make -C build` sequence (with whichever `-D` flags
select a given Remora variant) so a bare `make` at the root works the way
you'd expect.

`build.sh`'s `make` subcommand assumes a `Makefile` already exists at the
repo root and runs `--user "$(id -u):$(id -g)"` — convenient once you have
that top-level Makefile, but until then, use the explicit commands above
(or `./build.sh shell ~/code/ESCape32-aart` to drop into a container shell
and run the `cmake`/`make` sequence by hand).

Pass through extra make targets/args once `build/` exists, e.g. to flash a
specific target via ST-LINK (requires also passing through the USB device —
see below):
```bash
docker run --rm -v "$(pwd):/workspace" --user 501:20 aart/escape32-builder \
  make -C build flash-AART1
```

## Flashing from inside the container

`stlink-tools` is included, but Docker doesn't see USB devices by default. On Linux,
add `--device=/dev/ttyACM0` (or whatever your ST-LINK shows up as) to the `docker run`
invocations in `build.sh`, or just run `make flash-<target>` on the host instead — the
container is really for the cross-compile step, flashing is a one-line addition if you
want it but not essential.

## Bumping the toolchain or libopencm3 pin

```bash
docker build -t aart/escape32-builder \
  --build-arg LIBOPENCM3_REF=<new-commit-or-tag> \
  .
```

Bumping `gcc-arm-none-eabi` itself means bumping the base image (`ubuntu:24.04` ->
a newer Ubuntu, or switching to ARM's own toolchain release if you want a version
upstream specifically uses) — worth doing deliberately and re-testing flash-tight
targets afterward, not as a side effect of an unrelated rebuild.

## A note on a fix that didn't end up mattering

An earlier version of this image hit `exit code: 2` on the libopencm3 build
step. The first hypothesis was an Apple Silicon / arm64 architecture issue —
that turned out to be wrong. The real cause: libopencm3 generates
`nvic.h`/`vector_nvic.c`/`irqhandlers.h` per target family via a script
(`irq2nvic_h`) whose shebang is `#!/usr/bin/env python3`, and the image
never installed `python3`. It's in the apt-get list now. Confirmed by
reproducing the exact failure with `python3` removed and then fixing it by
adding it back, on the same pinned libopencm3 commit, both ways.

## Ubuntu vs. Arch base

`Dockerfile` (Ubuntu 24.04) is the one that's actually been built and run end to
end against the real ESCape32 source — that's the one to trust by default.

`Dockerfile.arch` is an Arch Linux alternative, pinned to a specific Arch Linux
Archive snapshot date so it doesn't drift the way a bare `pacman -Syu` would on
a rolling-release distro. Its packages were checked against archlinux.org but
it hasn't been build-tested the way the Ubuntu one has. Arch's official
`arm-none-eabi-gcc` is currently 14.2.0, a major version ahead of Ubuntu
24.04's 13.2.1 — worth bench-testing flash-tight targets against a build from
this image before relying on it, the same caution as above about toolchain
version affecting whether tight-flash targets fit.

To use it instead, build with `-f Dockerfile.arch` (or swap the filenames) and
everything else — `build.sh`, the GitHub Actions workflows — works unchanged.

## Files

- `Dockerfile` — the build environment image (Ubuntu-based, tested).
- `Dockerfile.arch` — Arch Linux alternative, pinned via Arch Linux Archive (untested).
- `build.sh` — convenience wrapper for building the image and running it against a
  mounted fork.
