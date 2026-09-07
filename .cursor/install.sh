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
