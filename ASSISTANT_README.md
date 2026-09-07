# Personal assistant (`assistant.py`)

A command-line assistant you can ask questions and get replies. Two modes:

- **chat** — general-purpose Q&A with an LLM.
- **data** — ask questions about the Shopdeck data; the assistant writes SQL,
  runs it against Metabase, and answers in plain English.

The LLM provider is **auto-detected**: it uses a cloud API key if one is set
(Anthropic, OpenAI, or Gemini), otherwise it falls back to a **local model** via
Ollama — so you can run it with **no API key and no cost**.

## Run with no API key (local model)

One-time setup, then it just works — no keys, no bills:

```bash
bash setup_local_model.sh          # installs Ollama + pulls a small model
python assistant.py                # auto-detects the local model
# or explicitly:
python assistant.py --provider ollama -q "What is a hash function?"
```

`setup_local_model.sh` installs Ollama, starts its server, and pulls
`llama3.2:1b` (a ~1.3 GB model that runs on CPU). Pick a different model with
`OLLAMA_MODEL=llama3.2:3b bash setup_local_model.sh` (bigger = better answers,
slower on CPU). Smaller/faster option: `qwen2.5:0.5b`.

Trade-off: a local 1B model is fast and free but less capable than a hosted
frontier model. For the best quality, add a cloud API key (below).

## Setup

Dependencies are already covered by `requirements.txt` (`requests`). If you
haven't set up the environment yet:

```bash
bash .cursor/install.sh
source .venv/bin/activate
```

For higher-quality answers, provide **one** cloud LLM API key (optional if you
use the local model above):

```bash
export ANTHROPIC_API_KEY="sk-ant-..."   # or
export OPENAI_API_KEY="sk-..."          # or
export GEMINI_API_KEY="..."             # Gemini has a generous free tier
```

Free/cheap options if you want a cloud model without much cost: Google Gemini's
free-tier API key, or Groq's free API (OpenAI-compatible).

## Usage

Interactive REPL:

```bash
python assistant.py
```

One-shot question:

```bash
python assistant.py -q "Explain consistent hashing in two sentences."
```

Try the interface with no API key (offline stub replies):

```bash
python assistant.py --provider mock -q "hello"
```

### REPL commands

| Command        | Action                                    |
|----------------|-------------------------------------------|
| `/help`        | Show help                                 |
| `/data`        | Switch to data mode (SQL via Metabase)    |
| `/chat`        | Switch to general chat mode               |
| `/mode`        | Show current mode, provider, and model    |
| `/model <name>`| Change the model                          |
| `/reset`       | Clear the conversation history            |
| `/exit`        | Quit                                      |

## Data mode

Data mode also needs Metabase access (reuses the same instance as
`metabase_pull.py`):

```bash
export METABASE_URL="https://metabase.kaip.in"
export METABASE_API_KEY="mb_..."
export METABASE_DATABASE_ID="2"          # or pass --database 2
```

Then:

```bash
python assistant.py --data -q "How many sellers are in each status?"
```

It prints the generated SQL, the result rows, and a plain-English answer.

## Options

| Flag            | Description                                             |
|-----------------|---------------------------------------------------------|
| `--provider`    | `auto` (default), `anthropic`, `openai`, `gemini`, `ollama` (local), `mock` |
| `--model`       | Override the model name                                  |
| `--data`        | Start in data mode                                       |
| `-q, --question`| Ask one question and exit                               |
| `--base-url`    | Metabase base URL (or `METABASE_URL`)                   |
| `--database`    | Metabase database ID (or `METABASE_DATABASE_ID`)        |

## Model overrides

Defaults can be changed per provider via env vars: `ANTHROPIC_MODEL`,
`OPENAI_MODEL`, `GEMINI_MODEL`, `OLLAMA_MODEL`, or the global `--model` flag. If a
default model name is rejected by the provider, pass `--model` with a current
model name. For the local server, override the address with `OLLAMA_HOST`.

## Notes

- No secrets are stored in the repo; keys are read from environment variables.
- The assistant talks to provider REST APIs directly via `requests` (no vendor
  SDKs), so it stays lightweight.
