#!/usr/bin/env bash
# Convenience wrapper around the escape32-builder image.
#
# Usage:
#   ./build.sh image                 Build/rebuild the builder image
#   ./build.sh shell <fork-dir>      Drop into an interactive shell with <fork-dir> mounted
#   ./build.sh make <fork-dir> [args...]   Run `make [args...]` inside <fork-dir>
#
# Examples:
#   ./build.sh image
#   ./build.sh make ~/code/ESCape32-aart
#   ./build.sh make ~/code/ESCape32-aart flash-AART1
#   ./build.sh shell ~/code/ESCape32-aart

set -euo pipefail

IMAGE_NAME="aart/escape32-builder"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cmd="${1:-}"
shift || true

case "$cmd" in
  image)
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    ;;
  shell)
    dir="${1:?Usage: ./build.sh shell <fork-dir>}"
    docker run --rm -it \
      -v "$(cd "$dir" && pwd):/workspace" \
      --user "$(id -u):$(id -g)" \
      "$IMAGE_NAME" bash
    ;;
  make)
    dir="${1:?Usage: ./build.sh make <fork-dir> [make-args...]}"
    shift
    docker run --rm \
      -v "$(cd "$dir" && pwd):/workspace" \
      --user "$(id -u):$(id -g)" \
      "$IMAGE_NAME" make "$@"
    ;;
  *)
    echo "Usage: $0 {image|shell <fork-dir>|make <fork-dir> [make-args...]}" >&2
    exit 1
    ;;
esac
