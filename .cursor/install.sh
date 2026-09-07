#!/usr/bin/env bash
# Idempotent development-environment bootstrap for the Shopdeck analytics repo.
#
# Creates a project-local Python virtual environment (.venv) and installs the
# pinned dependencies. Safe to run repeatedly: the venv is reused and pip skips
# already-satisfied requirements.
set -euo pipefail

cd "$(dirname "$0")/.."

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR=".venv"

# Ensure the stdlib venv module is usable. On Debian/Ubuntu the default image
# may ship Python without ensurepip, in which case the python3-venv package is
# required. Install it (best effort) only when venv creation would otherwise
# fail, so this stays a no-op on images/snapshots that already have it.
if ! "${PYTHON_BIN}" -c "import ensurepip" >/dev/null 2>&1; then
  echo "python venv support missing; attempting to install python3-venv ..."
  PY_MM="$("${PYTHON_BIN}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  if command -v sudo >/dev/null 2>&1; then APT="sudo apt-get"; else APT="apt-get"; fi
  ${APT} update -qq || true
  ${APT} install -y -qq "python${PY_MM}-venv" python3-pip || ${APT} install -y -qq python3-venv python3-pip || true
fi

if [ ! -x "${VENV_DIR}/bin/python" ]; then
  echo "Creating virtual environment in ${VENV_DIR} ..."
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo "Dependencies installed. Activate with: source ${VENV_DIR}/bin/activate"
python --version
python -c "import pandas, openpyxl, requests; print('pandas', pandas.__version__, '| openpyxl', openpyxl.__version__, '| requests', requests.__version__)"
