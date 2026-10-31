#!/usr/bin/env bash
# Build ZMK firmware locally with Docker, mirroring the GitHub Actions workflow.
#
# Usage:
#   scripts/build.sh                     # build every target in build.yaml
#   scripts/build.sh Corne_right_oled    # build only the given artifact names
#   scripts/build.sh --update ...        # force `west update` (after editing config/west.yml)
#   scripts/build.sh --list              # list artifact names from build.yaml
#
# Output: firmware/<artifact-name>.uf2
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${ZMK_IMAGE:-zmkfirmware/zmk-build-arm:stable}"

tty_args=()
[ -t 0 ] && tty_args=(-it)

docker run --rm "${tty_args[@]}" \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -v "${REPO_DIR}:/repo" \
    -w /repo \
    "${IMAGE}" \
    bash /repo/scripts/build-in-container.sh "$@"
