# Metabase MCP Server

This repo is configured to connect to Metabase via the Model Context Protocol,
so you can run SQL queries and interact with dashboards/cards directly from
Claude Code. Configuration lives in [`.mcp.json`](./.mcp.json).

## Provide credentials

The config reads two environment variables (no secrets are stored in the repo):

- `METABASE_URL` — your Metabase instance URL, e.g. `https://metabase.yourcompany.com`
- `METABASE_API_KEY` — an API key from Metabase → Admin settings → Authentication → API Keys

For Claude Code on the web, set these as environment variables in your
environment settings so they're available to every session. Locally, export
them in your shell before launching Claude Code:

```bash
export METABASE_URL="https://metabase.yourcompany.com"
export METABASE_API_KEY="mb_xxxxxxxxxxxxxxxx"
```

If you don't have an API key, you can instead use username/password auth by
setting `METABASE_USERNAME` and `METABASE_PASSWORD` in `.mcp.json` env block.

## Using it

Once the env vars are set, start (or restart) Claude Code and approve the
`metabase` MCP server when prompted. The server exposes tools including:

- `execute_query` — run raw SQL against a connected database
- `execute_card` / `execute_dashboard_query` — run existing questions/dashboards
- Database, table, card, and dashboard management tools

You can then ask things like *"run this SQL on database X"* and the query runs
directly against Metabase.
