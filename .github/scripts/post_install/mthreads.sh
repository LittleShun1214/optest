#!/usr/bin/env bash
# Build FlagCX against the final MThreads torch stack and validate the
# complete vLLM/vllm-musa runtime installed by the target repository.
set -euo pipefail
export TORCH_DEVICE_BACKEND_AUTOLOAD=0

TARGET="${TARGET_DIR:-FlagGems-vllm}"
ROOT="${GITHUB_WORKSPACE:-$PWD}"
WRAPPER="${ROOT}/${TARGET}/tools/flagcx_wrapper/build_flagcx_wheel.sh"

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

