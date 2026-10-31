#!/usr/bin/env bash
# Runs inside the zmk-build-arm container. Use scripts/build.sh instead of calling this directly.
set -euo pipefail

REPO=/repo
WORKSPACE="${REPO}/.zmk"
OUT_DIR="${REPO}/firmware"

force_update=false
list_only=false
targets=()
for arg in "$@"; do
    case "${arg}" in
        --update) force_update=true ;;
        --list) list_only=true ;;
        *) targets+=("${arg}") ;;
    esac
done

# One line per target: artifact|board|shield|snippet
matrix=$(python3 - "${REPO}/build.yaml" <<'EOF'
import sys, yaml
for entry in yaml.safe_load(open(sys.argv[1]))["include"]:
    board = entry["board"]
    shield = entry.get("shield", "")
    name = entry.get("artifact-name") or "-".join(filter(None, [shield.replace(" ", "-"), board]))
    print(f"{name}|{board}|{shield}|{entry.get('snippet', '')}")
EOF
)

if ${list_only}; then
    cut -d'|' -f1 <<<"${matrix}"
    exit 0
fi

# West workspace lives in .zmk/ (git-ignored); the manifest is a copy of config/west.yml.
mkdir -p "${WORKSPACE}/config"
if ! cmp -s "${REPO}/config/west.yml" "${WORKSPACE}/config/west.yml"; then
    cp "${REPO}/config/west.yml" "${WORKSPACE}/config/west.yml"
    force_update=true
fi
cd "${WORKSPACE}"
if [ ! -d .west ]; then
    west init -l config
    force_update=true
fi
if ${force_update}; then
    west update --fetch-opt=--filter=tree:0
    west zephyr-export
fi

mkdir -p "${OUT_DIR}"
built=()
failed=()
while IFS='|' read -r name board shield snippet; do
    if [ ${#targets[@]} -gt 0 ] && [[ ! " ${targets[*]} " =~ " ${name} " ]]; then
        continue
    fi
    echo "==> Building ${name} (board=${board} shield='${shield}' snippet='${snippet}')"
    snippet_args=()
    [ -n "${snippet}" ] && snippet_args=(-S "${snippet}")
    if west build -p auto -s zmk/app -d "build/${name}" -b "${board}" "${snippet_args[@]}" -- \
        -DZMK_CONFIG="${REPO}/config" \
        -DSHIELD="${shield}" \
        -DZMK_EXTRA_MODULES="${REPO}"; then
        cp "build/${name}/zephyr/zmk.uf2" "${OUT_DIR}/${name}.uf2"
        built+=("${name}")
    else
        failed+=("${name}")
    fi
done <<<"${matrix}"

echo
echo "Built:  ${built[*]:-none}"
echo "Failed: ${failed[*]:-none}"
echo "Output: firmware/"
[ ${#failed[@]} -eq 0 ]
