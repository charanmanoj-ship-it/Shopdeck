# Personal assistant (`assistant.py`)

A command-line assistant you can ask questions and get replies. Two modes:

- **chat** — general-purpose Q&A with an LLM.
- **data** — ask questions about the Shopdeck data; the assistant writes SQL,
  runs it against Metabase, and answers in plain English.

The LLM provider is **auto-detected** from whichever API key is set, so you can
use Anthropic, OpenAI, or Gemini without changing anything.

## Setup

Dependencies are already covered by `requirements.txt` (`requests`). If you
haven't set up the environment yet:

```bash
bash .cursor/install.sh
source .venv/bin/activate
```

Then provide **one** LLM API key:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."   # or
export OPENAI_API_KEY="sk-..."          # or
export GEMINI_API_KEY="..."
```

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
| `--provider`    | `auto` (default), `anthropic`, `openai`, `gemini`, `mock` |
| `--model`       | Override the model name                                  |
| `--data`        | Start in data mode                                       |
| `-q, --question`| Ask one question and exit                               |
| `--base-url`    | Metabase base URL (or `METABASE_URL`)                   |
| `--database`    | Metabase database ID (or `METABASE_DATABASE_ID`)        |

## Model overrides

Defaults can be changed per provider via env vars: `ANTHROPIC_MODEL`,
`OPENAI_MODEL`, `GEMINI_MODEL`, or the global `--model` flag. If a default model
name is rejected by the provider, pass `--model` with a current model name.

## Notes

- No secrets are stored in the repo; keys are read from environment variables.
- The assistant talks to provider REST APIs directly via `requests` (no vendor
  SDKs), so it stays lightweight.
