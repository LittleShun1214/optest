#!/usr/bin/env bash
# Build FlagCX against the final MThreads torch stack and validate the final
# MUSA runtime. vLLM checks apply only to the FlagGems-vllm target.
set -euo pipefail
export TORCH_DEVICE_BACKEND_AUTOLOAD=0

TARGET="${TARGET_DIR:-FlagGems-vllm}"
ROOT="${GITHUB_WORKSPACE:-$PWD}"
WRAPPER="${ROOT}/${TARGET}/tools/flagcx_wrapper/build_flagcx_wheel.sh"

TARGET_NAME="${TARGET_REPOSITORY:-}"
TARGET_NAME="${TARGET_NAME##*/}"
if [ -z "${TARGET_NAME}" ]; then
  TARGET_NAME="$(basename "${TARGET}")"
fi
if [ -z "${TARGET_NAME}" ]; then
  TARGET_NAME="FlagGems-vllm"
fi
IS_FLAGGEMS_VLLM=0
if [ "${TARGET_NAME}" = "FlagGems-vllm" ]; then
  IS_FLAGGEMS_VLLM=1
fi

if [ -x "${WRAPPER}" ]; then
  OUT="$(mktemp -d)"
  trap 'rm -rf "${OUT}"' EXIT
  FLAGCX_ADAPTOR=musa "${WRAPPER}" "${OUT}"
  WHEEL="$(ls "${OUT}"/flagcx-*.whl | head -1)"
  echo "[Post-install script] installing ${WHEEL}"
  uv pip install --python "$(command -v python3)" --force-reinstall --no-deps "${WHEEL}"
else
  echo "[Post-install script] no FlagCX wrapper at ${WRAPPER}"
fi

if [ "${IS_FLAGGEMS_VLLM}" -ne 1 ]; then
  python3 - "${TARGET_NAME}" <<'PY'
import sys

import torch_musa
import torch

assert torch.musa.is_available(), "torch.musa is not available"
print(
    f"[Post-install script] {sys.argv[1]}: non-vLLM target; "
    "MUSA torch runtime OK"
)
PY
  exit 0
fi

python3 - <<'PY'
import importlib.metadata as md

import torch_musa
import torch
import vllm
import vllm_musa
from vllm.platforms import current_platform

assert torch.musa.is_available(), "torch.musa is not available"
assert vllm.__version__.split("+")[0] == "0.32.0", vllm.__version__
assert vllm_musa.__version__ == "0.1.32", vllm_musa.__version__
assert current_platform.is_musa(), type(current_platform)

groups = {ep.group for ep in md.distribution("vllm-musa").entry_points}
assert "vllm.platform_plugins" in groups, groups
assert "vllm.general_plugins" in groups, groups
print("[Post-install script] MUSA vLLM platform OK")
PY
