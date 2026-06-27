# Metabase data pull

`metabase_pull.py` pulls data from Metabase (https://metabase.kaip.in) via its
REST API and saves it to a file. Run it **on a machine that can reach Metabase**
(your laptop or CI) — the Claude-on-the-web sandbox has restricted network
egress and cannot reach `metabase.kaip.in` directly.

## Setup

```bash
pip install requests

# Create an API key in Metabase: Admin -> Settings -> Authentication -> API Keys
export METABASE_API_KEY="mb_xxxxxxxx"     # never commit this
# optional: override the host (defaults to https://metabase.kaip.in)
# export METABASE_URL="https://metabase.kaip.in"
```

## Usage

**Named shortcut** — pre-configured saved questions, no IDs to remember:

```bash
python metabase_pull.py --ob-cohort --format xlsx --out ob_cohort.xlsx
```

Currently configured shortcuts:

| Flag          | Saved question                                              |
|---------------|-------------------------------------------------------------|
| `--ob-cohort` | #7100 `ob-cohort-query-v2` (metabase.kaip.in/question/7100) |

Add more in `metabase_pull.py` under `NAMED_QUERIES`.

**Saved question (card)** — find the card ID in the question URL,
e.g. `https://metabase.kaip.in/question/123` -> card ID is `123`:

```bash
python metabase_pull.py --card 123 --format xlsx --out report.xlsx
```

**Ad-hoc SQL** — needs the database ID (Admin -> Databases, or the
`/admin/databases/<id>` URL):

```bash
python metabase_pull.py \
  --sql "SELECT * FROM orders WHERE created_at >= '2026-01-01' LIMIT 1000" \
  --database 2 --format csv --out orders.csv
```

## Options

| Flag         | Description                                           |
|--------------|-------------------------------------------------------|
| `--card`     | Saved question (card) ID to run.                      |
| `--sql`      | Ad-hoc native SQL (requires `--database`).            |
| `--database` | Database ID (used with `--sql`).                      |
| `--format`   | `xlsx` (default), `csv`, or `json`.                   |
| `--out`      | Output file path (default `metabase_export.<format>`).|
| `--base-url` | Override the Metabase host (or set `METABASE_URL`).   |

## Notes

- The API key is read from the `METABASE_API_KEY` environment variable and is
  never written to disk or hardcoded. Do not paste it into commits or chat.
- Output uses Metabase's native export endpoints, so files come back already
  formatted (real `.xlsx`, proper CSV, etc.).
