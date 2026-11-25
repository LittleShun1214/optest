#!/usr/bin/env bash
# Build the target repository's FlagCX wrapper after the torch stack is
# installed.  The wrapper must see the final torch ABI.
set -euo pipefail
TARGET="${TARGET_DIR:-FlagGems-vllm}"
WRAPPER="${GITHUB_WORKSPACE:-$PWD}/${TARGET}/tools/flagcx_wrapper/build_flagcx_wheel.sh"
if [ ! -x "${WRAPPER}" ]; then
  echo "[Post-install script] no FlagCX wrapper at ${WRAPPER}"
  exit 0
fi
OUT="$(mktemp -d)"
trap 'rm -rf "${OUT}"' EXIT
"${WRAPPER}" "${OUT}"
WHEEL="$(ls "${OUT}"/flagcx-*.whl | head -1)"
echo "[Post-install script] installing ${WHEEL}"
uv pip install --python "$(command -v python3)" --force-reinstall --no-deps "${WHEEL}"
