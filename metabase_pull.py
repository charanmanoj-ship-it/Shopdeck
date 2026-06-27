#!/usr/bin/env python3
"""
Pull data from Metabase via its REST API and save it to a file.

Auth uses a Metabase API key, read from the METABASE_API_KEY environment
variable (never hardcode it). Create one in Metabase under:
    Admin -> Settings -> Authentication -> API Keys

Two modes:
  1. Saved question  ->  --card <CARD_ID>
  2. Ad-hoc SQL      ->  --sql "<QUERY>" --database <DATABASE_ID>

Output formats: xlsx (default), csv, json. The script uses Metabase's
native export endpoints, so the file comes back already formatted.

Examples
--------
  export METABASE_API_KEY="mb_xxx..."

  # Saved question #123 -> Excel
  python metabase_pull.py --card 123 --format xlsx --out report.xlsx

  # Ad-hoc SQL against database #2 -> CSV
  python metabase_pull.py --sql "SELECT * FROM orders LIMIT 100" \
      --database 2 --format csv --out orders.csv

Requires: requests  (pip install requests)
"""

import argparse
import json
import os
import sys
import urllib.parse

import requests

DEFAULT_BASE_URL = "https://metabase.kaip.in"
VALID_FORMATS = ("xlsx", "csv", "json")

# Named shortcuts for frequently-used saved questions.
# Add more as { "shortcut-name": card_id }.  Each becomes a --flag, e.g.
#   python metabase_pull.py --ob-cohort
NAMED_QUERIES = {
    "ob-cohort": 7100,  # https://metabase.kaip.in/question/7100-ob-cohort-query-v2
}


def build_session(api_key: str) -> requests.Session:
    session = requests.Session()
    session.headers.update({"x-api-key": api_key})
    return session


def export_card(session, base_url, card_id, fmt):
    """Run a saved question and return the exported bytes."""
    url = f"{base_url}/api/card/{card_id}/query/{fmt}"
    resp = session.post(url, timeout=300)
    resp.raise_for_status()
    return resp.content


def export_sql(session, base_url, database_id, query, fmt):
    """Run ad-hoc native SQL and return the exported bytes."""
    url = f"{base_url}/api/dataset/{fmt}"
    payload = {
        "database": database_id,
        "type": "native",
        "native": {"query": query},
    }
    # The export endpoint expects the query JSON form-encoded under `query`.
    resp = session.post(
        url,
        data={"query": json.dumps(payload)},
        timeout=300,
    )
    resp.raise_for_status()
    return resp.content


def parse_args(argv):
    p = argparse.ArgumentParser(
        description="Pull data from Metabase via its REST API.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--base-url",
        default=os.environ.get("METABASE_URL", DEFAULT_BASE_URL),
        help=f"Metabase base URL (default: env METABASE_URL or {DEFAULT_BASE_URL})",
    )
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--card", type=int, help="Saved question (card) ID to run.")
    src.add_argument("--sql", help="Ad-hoc native SQL query to run.")
    for name, card_id in NAMED_QUERIES.items():
        src.add_argument(
            f"--{name}",
            action="store_true",
            help=f"Shortcut for saved question #{card_id}.",
        )
    p.add_argument(
        "--database",
        type=int,
        help="Database ID (required with --sql).",
    )
    p.add_argument(
        "--format",
        choices=VALID_FORMATS,
        default="xlsx",
        help="Output format (default: xlsx).",
    )
    p.add_argument(
        "--out",
        help="Output file path (default: metabase_export.<format>).",
    )
    args = p.parse_args(argv)
    # Resolve a named shortcut (e.g. --ob-cohort) into a concrete card ID.
    for name, card_id in NAMED_QUERIES.items():
        if getattr(args, name.replace("-", "_")):
            args.card = card_id
    if args.sql and args.database is None:
        p.error("--database is required when using --sql")
    return args


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])

    api_key = os.environ.get("METABASE_API_KEY")
    if not api_key:
        sys.exit(
            "ERROR: METABASE_API_KEY is not set.\n"
            "  export METABASE_API_KEY=\"mb_...\"   (do not hardcode it)"
        )

    base_url = args.base_url.rstrip("/")
    out_path = args.out or f"metabase_export.{args.format}"
    session = build_session(api_key)

    try:
        if args.card is not None:
            print(f"Running saved question #{args.card} ...", file=sys.stderr)
            content = export_card(session, base_url, args.card, args.format)
        else:
            print(
                f"Running ad-hoc SQL against database #{args.database} ...",
                file=sys.stderr,
            )
            content = export_sql(
                session, base_url, args.database, args.sql, args.format
            )
    except requests.HTTPError as e:
        status = e.response.status_code if e.response is not None else "?"
        body = e.response.text[:500] if e.response is not None else ""
        sys.exit(f"ERROR: Metabase returned HTTP {status}\n{body}")
    except requests.RequestException as e:
        sys.exit(f"ERROR: request to Metabase failed: {e}")

    with open(out_path, "wb") as fh:
        fh.write(content)

    print(f"Wrote {len(content):,} bytes to {out_path}")


if __name__ == "__main__":
    main()
