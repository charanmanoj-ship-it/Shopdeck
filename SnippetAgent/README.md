# SnippetAgent

AgentCore project that generates copy-paste **HTML, CSS, and JavaScript** snippets for websites.

- **Framework:** Strands
- **Model:** Anthropic Claude (`claude-sonnet-4-5-20250929`)
- **Protocol:** HTTP
- **Build:** CodeZip
- **Memory:** none (can be added later)

This is a snippet *generator*, not an embeddable chat widget. Call it with a prompt; it returns three fenced code blocks you can paste into a page.

## Preview a sample (no API key)

Live generation uses Claude and needs Anthropic **API credits** (a chat subscription is not enough). Until credits are on the account, open the sample pricing cards:

```bash
python3 -m http.server 8765 --directory examples
```

Then open http://127.0.0.1:8765/pricing-card.html — three plans (Starter, Pro, Enterprise) and a monthly/yearly switch.

## Prerequisites

- Node.js 20+
- Python 3.10+ and [uv](https://docs.astral.sh/uv/)
- AgentCore CLI: `npm install -g @aws/agentcore` (v0.9.0+)
- `ANTHROPIC_API_KEY` in `SnippetAgent/agentcore/.env.local` for local runs (never commit this file, never paste the key in chat)
- AWS credentials only when you are ready to deploy

## Local development

From this directory (`SnippetAgent/`):

```bash
# agentcore/.env.local
ANTHROPIC_API_KEY=sk-ant-...

agentcore dev
```

In another terminal:

```bash
agentcore invoke --dev "Give me a responsive HTML/CSS/JS pricing card snippet."
```

Or with curl (default HTTP port is `8080`; the CLI prints the bound port if it had to increment):

```bash
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{"prompt": "sticky header with a mobile hamburger menu"}'
```

## Tests (no API key)

```bash
cd app/SnippetAgent
uv run python -m unittest test_snippet_agent.py
```

## Deploy

```bash
agentcore deploy
agentcore invoke "Give me a responsive HTML/CSS pricing card snippet."
```

First deploy needs AWS credentials, Bedrock AgentCore permissions, and an Anthropic credential in AgentCore Identity. Putting this on a public website comes after deploy (`agentcore fetch access`); default auth is IAM.

## Project layout

```
SnippetAgent/
├── examples/pricing-card.html # sample you can open without an API key
├── agentcore/                 # CLI config, CDK, gitignored .env.local
└── app/SnippetAgent/
    ├── main.py                # snippet-generator prompt + HTTP entrypoint
    ├── model/load.py          # Anthropic Claude model + ANTHROPIC_API_KEY
    └── test_snippet_agent.py
```
