#!/usr/bin/env bash
# Set up a local LLM so the assistant runs with NO API key and NO cost.
#
# Installs Ollama, starts its server, and pulls a small model. Idempotent:
# re-running skips anything already present. After this, run:
#
#     python assistant.py --provider ollama
#
# Environment overrides:
#   OLLAMA_MODEL   model to pull/use (default: llama3.2:1b)
#   OLLAMA_HOST    server address    (default: 127.0.0.1:11434)
set -euo pipefail

MODEL="${OLLAMA_MODEL:-llama3.2:1b}"
HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
API="http://${HOST}"

if command -v sudo >/dev/null 2>&1; then APT="sudo apt-get"; else APT="apt-get"; fi

# The Ollama installer needs zstd to unpack its archive on Debian/Ubuntu.
if ! command -v zstd >/dev/null 2>&1; then
  echo "Installing zstd (required to unpack Ollama) ..."
  ${APT} update -qq || true
  ${APT} install -y -qq zstd || true
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "Installing Ollama ..."
  curl -fsSL https://ollama.com/install.sh | sh
fi

# Start the server if it isn't already answering. systemd is not always
# available in containers, so start it in the background as a fallback.
if ! curl -sf --max-time 3 "${API}/api/tags" >/dev/null 2>&1; then
  echo "Starting Ollama server ..."
  OLLAMA_HOST="${HOST}" nohup ollama serve >/tmp/ollama_serve.log 2>&1 &
  for _ in $(seq 1 30); do
    curl -sf --max-time 2 "${API}/api/tags" >/dev/null 2>&1 && break
    sleep 1
  done
fi

if ! curl -sf --max-time 3 "${API}/api/tags" >/dev/null 2>&1; then
  echo "ERROR: Ollama server did not come up. See /tmp/ollama_serve.log" >&2
  exit 1
fi

if ! curl -sf "${API}/api/tags" | grep -q "\"${MODEL}\""; then
  echo "Pulling model ${MODEL} (one-time download) ..."
  ollama pull "${MODEL}"
fi

echo "Local model ready: ${MODEL} at ${API}"
echo "Run:  python assistant.py --provider ollama"
