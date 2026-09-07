#!/usr/bin/env python3
"""
Personal CLI assistant.

Two modes in one tool:
  * chat  — general-purpose Q&A with an LLM.
  * data  — ask questions about the Shopdeck data: the assistant writes SQL,
            runs it against Metabase, and answers in plain English.

Provider is auto-detected from whichever API key is set (Anthropic, OpenAI,
or Gemini). No secrets are hardcoded — everything comes from the environment.

Quick start
-----------
    export ANTHROPIC_API_KEY="sk-ant-..."      # or OPENAI_API_KEY / GEMINI_API_KEY
    python assistant.py                         # interactive REPL
    python assistant.py -q "What's a good hash function?"
    python assistant.py --data -q "How many sellers churned last month?"

REPL commands
-------------
    /help            show help
    /data            switch to data mode (SQL against Metabase)
    /chat            switch to general chat mode
    /mode            show the current mode and provider/model
    /model <name>    change the model
    /reset           clear the conversation history
    /exit, /quit     leave

Data mode needs (in addition to an LLM key):
    export METABASE_URL="https://metabase.kaip.in"
    export METABASE_API_KEY="mb_..."
    export METABASE_DATABASE_ID="2"            # or pass --database

Requires: requests
"""

import argparse
import json
import os
import re
import sys

import requests

DEFAULT_MODELS = {
    "anthropic": os.environ.get("ANTHROPIC_MODEL", "claude-3-5-sonnet-latest"),
    "openai": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
    "gemini": os.environ.get("GEMINI_MODEL", "gemini-1.5-flash"),
    "ollama": os.environ.get("OLLAMA_MODEL", "llama3.2:1b"),
    "mock": "mock-1",
}

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")

CHAT_SYSTEM = (
    "You are a helpful, concise personal assistant. Answer the user's questions "
    "directly and clearly. If you are unsure, say so."
)

SQL_SYSTEM = (
    "You are a senior SQL analyst for the Shopdeck seller database. "
    "Given a business question, return ONLY a single valid SQL query that answers "
    "it — no explanation, no prose, no markdown outside the query. "
    "Prefer standard SQL. Add a sensible LIMIT when the result could be large."
)

ANSWER_SYSTEM = (
    "You are a data analyst. You are given a business question, the SQL that was "
    "run, and the JSON result rows. Answer the question in plain English, citing "
    "the concrete numbers from the result. Be concise."
)


class ProviderError(Exception):
    pass


def ollama_available():
    """True if a local Ollama server is reachable (no API key needed)."""
    try:
        return requests.get(f"{OLLAMA_HOST}/api/tags", timeout=2).status_code == 200
    except requests.RequestException:
        return False


def detect_provider():
    """Pick a provider based on available keys, then a local Ollama server.

    Order: explicit cloud API keys first, then a running local Ollama (free,
    no key). Returns None if nothing usable is found.
    """
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("OPENAI_API_KEY"):
        return "openai"
    if os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"):
        return "gemini"
    if ollama_available():
        return "ollama"
    return None


class LLM:
    """Thin multi-provider chat client over plain HTTP (no vendor SDKs)."""

    def __init__(self, provider, model=None, timeout=90):
        self.provider = provider
        self.model = model or DEFAULT_MODELS.get(provider)
        self.timeout = timeout

    def complete(self, system, messages):
        """messages: list of {"role": "user"|"assistant", "content": str} -> str."""
        handler = {
            "anthropic": self._anthropic,
            "openai": self._openai,
            "gemini": self._gemini,
            "ollama": self._ollama,
            "mock": self._mock,
        }.get(self.provider)
        if handler is None:
            raise ProviderError(f"Unknown provider: {self.provider}")
        return handler(system, messages)

    def _anthropic(self, system, messages):
        key = os.environ["ANTHROPIC_API_KEY"]
        resp = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": self.model,
                "max_tokens": 1024,
                "system": system,
                "messages": messages,
            },
            timeout=self.timeout,
        )
        self._raise_for_status(resp)
        blocks = resp.json().get("content", [])
        return "".join(b.get("text", "") for b in blocks if b.get("type") == "text").strip()

    def _openai(self, system, messages):
        key = os.environ["OPENAI_API_KEY"]
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {key}"},
            json={
                "model": self.model,
                "messages": [{"role": "system", "content": system}] + messages,
            },
            timeout=self.timeout,
        )
        self._raise_for_status(resp)
        return resp.json()["choices"][0]["message"]["content"].strip()

    def _gemini(self, system, messages):
        key = os.environ.get("GEMINI_API_KEY") or os.environ["GOOGLE_API_KEY"]
        contents = [
            {
                "role": "model" if m["role"] == "assistant" else "user",
                "parts": [{"text": m["content"]}],
            }
            for m in messages
        ]
        resp = requests.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent",
            params={"key": key},
            json={
                "contents": contents,
                "systemInstruction": {"parts": [{"text": system}]},
            },
            timeout=self.timeout,
        )
        self._raise_for_status(resp)
        cand = resp.json()["candidates"][0]
        return "".join(p.get("text", "") for p in cand["content"]["parts"]).strip()

    def _ollama(self, system, messages):
        """Local model via Ollama's chat API — no API key, runs on this machine."""
        resp = requests.post(
            f"{OLLAMA_HOST}/api/chat",
            json={
                "model": self.model,
                "messages": [{"role": "system", "content": system}] + messages,
                "stream": False,
            },
            timeout=self.timeout,
        )
        if resp.status_code >= 400:
            raise ProviderError(
                f"Ollama HTTP {resp.status_code}: {resp.text[:500]}\n"
                f"Is the model pulled? Try: ollama pull {self.model}"
            )
        return resp.json()["message"]["content"].strip()

    def _mock(self, system, messages):
        """Offline stub so the tool is runnable without any API key."""
        last = messages[-1]["content"] if messages else ""
        if system == SQL_SYSTEM:
            return (
                "```sql\n"
                "SELECT status, COUNT(*) AS sellers\n"
                "FROM sellers\n"
                "GROUP BY status\n"
                "ORDER BY sellers DESC;\n"
                "```"
            )
        if system == ANSWER_SYSTEM:
            return "[mock] Based on the result rows, here is a plain-English summary."
        return (
            f"[mock:{self.model}] You said: {last}\n"
            "This is an offline stub reply. Set an API key "
            "(ANTHROPIC_API_KEY / OPENAI_API_KEY / GEMINI_API_KEY) for real answers."
        )

    @staticmethod
    def _raise_for_status(resp):
        if resp.status_code >= 400:
            body = resp.text[:500]
            raise ProviderError(f"HTTP {resp.status_code} from provider:\n{body}")


class Metabase:
    """Runs native SQL through Metabase's dataset endpoint."""

    def __init__(self, base_url, api_key, database_id, timeout=300):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.database_id = int(database_id)
        self.timeout = timeout

    def run_sql(self, sql):
        resp = requests.post(
            f"{self.base_url}/api/dataset",
            headers={"x-api-key": self.api_key, "content-type": "application/json"},
            json={
                "database": self.database_id,
                "type": "native",
                "native": {"query": sql},
            },
            timeout=self.timeout,
        )
        if resp.status_code >= 400:
            raise ProviderError(f"Metabase HTTP {resp.status_code}: {resp.text[:500]}")
        data = resp.json().get("data", {})
        cols = [c["name"] for c in data.get("cols", [])]
        rows = data.get("rows", [])
        return [dict(zip(cols, row)) for row in rows]


def extract_sql(text):
    """Pull a SQL query out of an LLM reply that may be fenced in ```sql blocks."""
    fenced = re.search(r"```(?:sql)?\s*(.*?)```", text, re.DOTALL | re.IGNORECASE)
    return (fenced.group(1) if fenced else text).strip().rstrip(";").strip() + ";"


def build_metabase(args):
    url = args.base_url or os.environ.get("METABASE_URL")
    key = os.environ.get("METABASE_API_KEY")
    db = args.database or os.environ.get("METABASE_DATABASE_ID")
    missing = [
        name
        for name, val in (
            ("METABASE_URL", url),
            ("METABASE_API_KEY", key),
            ("METABASE_DATABASE_ID/--database", db),
        )
        if not val
    ]
    if missing:
        raise ProviderError(
            "Data mode needs: " + ", ".join(missing) + ".\n"
            "Set them and try again (see --help)."
        )
    return Metabase(url, key, db)


def answer_data_question(llm, metabase, question):
    sql_reply = llm.complete(SQL_SYSTEM, [{"role": "user", "content": question}])
    sql = extract_sql(sql_reply)
    rows = metabase.run_sql(sql)
    preview = json.dumps(rows[:50], default=str)[:6000]
    summary = llm.complete(
        ANSWER_SYSTEM,
        [
            {
                "role": "user",
                "content": (
                    f"Question: {question}\n\nSQL:\n{sql}\n\n"
                    f"Result rows (JSON):\n{preview}\n\nAnswer the question."
                ),
            }
        ],
    )
    return sql, rows, summary


def print_data_result(sql, rows, summary):
    print("\n\033[2m-- SQL --------------------------------------------------\033[0m")
    print(sql)
    print(f"\033[2m-- {len(rows)} row(s) ------------------------------------\033[0m")
    for r in rows[:10]:
        print("  " + json.dumps(r, default=str))
    if len(rows) > 10:
        print(f"  ... and {len(rows) - 10} more")
    print("\n" + summary + "\n")


def run_repl(llm, args):
    mode = "data" if args.data else "chat"
    history = []
    print(
        f"Personal assistant ready (provider={llm.provider}, model={llm.model}, "
        f"mode={mode}). Type /help for commands, /exit to quit."
    )
    while True:
        try:
            line = input(f"\n[{mode}] > ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return
        if not line:
            continue
        if line in ("/exit", "/quit"):
            return
        if line == "/help":
            print(__doc__)
            continue
        if line == "/data":
            mode = "data"
            print("Switched to data mode.")
            continue
        if line == "/chat":
            mode = "chat"
            print("Switched to chat mode.")
            continue
        if line == "/mode":
            print(f"mode={mode}, provider={llm.provider}, model={llm.model}")
            continue
        if line.startswith("/model "):
            llm.model = line.split(" ", 1)[1].strip()
            print(f"Model set to {llm.model}")
            continue
        if line == "/reset":
            history = []
            print("Conversation cleared.")
            continue
        if line.startswith("/"):
            print(f"Unknown command: {line} (try /help)")
            continue

        try:
            if mode == "data":
                metabase = build_metabase(args)
                sql, rows, summary = answer_data_question(llm, metabase, line)
                print_data_result(sql, rows, summary)
            else:
                history.append({"role": "user", "content": line})
                reply = llm.complete(CHAT_SYSTEM, history)
                history.append({"role": "assistant", "content": reply})
                print("\n" + reply)
        except ProviderError as e:
            print(f"\n[error] {e}")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Personal CLI assistant (general chat + Shopdeck data mode).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--provider",
        choices=["auto", "anthropic", "openai", "gemini", "ollama", "mock"],
        default="auto",
        help="LLM provider. 'auto' uses an API key if set, else a local Ollama "
        "server if running. 'ollama' forces the local (no-key) model.",
    )
    parser.add_argument("--model", help="Override the model name.")
    parser.add_argument(
        "--data", action="store_true", help="Start in data mode (SQL via Metabase)."
    )
    parser.add_argument("-q", "--question", help="Ask one question and exit.")
    parser.add_argument("--base-url", help="Metabase base URL (or set METABASE_URL).")
    parser.add_argument("--database", help="Metabase database ID (or METABASE_DATABASE_ID).")
    args = parser.parse_args(argv if argv is not None else sys.argv[1:])

    provider = args.provider
    if provider == "auto":
        provider = detect_provider()
        if provider is None:
            print(
                "No usable LLM found. Options:\n"
                "  * Run a local model (no API key, free):\n"
                "      curl -fsSL https://ollama.com/install.sh | sh\n"
                "      ollama serve &   &&   ollama pull llama3.2:1b\n"
                "      python assistant.py --provider ollama\n"
                "  * Or set an API key: ANTHROPIC_API_KEY / OPENAI_API_KEY / GEMINI_API_KEY\n"
                "  * Or try the interface offline with: --provider mock",
                file=sys.stderr,
            )
            return 2

    llm = LLM(provider, model=args.model)

    if args.question:
        try:
            if args.data:
                metabase = build_metabase(args)
                sql, rows, summary = answer_data_question(llm, metabase, args.question)
                print_data_result(sql, rows, summary)
            else:
                reply = llm.complete(CHAT_SYSTEM, [{"role": "user", "content": args.question}])
                print(reply)
        except ProviderError as e:
            print(f"[error] {e}", file=sys.stderr)
            return 1
        return 0

    run_repl(llm, args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
