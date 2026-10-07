import json
import re
from datetime import date, datetime

from shopdeck_bot import queries
from shopdeck_bot.digest import DigestData, StuckSeller, build_blocks, fallback_text

ALL_SQL = {
    "TASK_COMPLETIONS": queries.TASK_COMPLETIONS,
    "LAUNCHES": queries.LAUNCHES,
    "LIFECYCLE_EVENTS": queries.LIFECYCLE_EVENTS,
    "STUCK_META_TO_FT": queries.STUCK_META_TO_FT,
}


def _data(stuck_count=3):
    stuck = [StuckSeller(f"S{i}", datetime(2026, 9, 25), 12 - i % 3, ["Asha", "Ravi"][i % 2])
             for i in range(stuck_count)]
    return DigestData(
        report_date=date(2026, 10, 6),
        launches=17,
        completions={"meta_setup": 40, "fund_transfer": 22},
        lifecycle={"paused": 2, "unpaused": 1, "revived": 0, "churned": 3},
        stuck=stuck,
    )


def test_every_partitioned_table_reference_has_created_at_filter():
    # Each FROM over a partitioned table must be followed (within its CTE/statement) by a created_at bound.
    for name, sql in ALL_SQL.items():
        chunks = re.split(r"FROM `", sql)[1:]
        for chunk in chunks:
            table = chunk.split("`")[0].rsplit(".", 1)[-1]
            if table == "users":
                continue
            body = chunk.split("\n)")[0]
            assert "created_at >=" in body and "created_at <" in body, f"{name}: {table} missing partition filter"


def test_poc_routing_prefers_open_ft_assignee_over_ticket_poc():
    sql = queries.STUCK_META_TO_FT
    assert "users` u ON u._id = COALESCE(o.assigned_poc, t.ob_poc)" in sql
    assert "u.email AS poc_email" in sql


def test_blocks_render_all_task_types_and_counts():
    blocks = build_blocks(_data(), stuck_after_days=7, stuck_list_limit=15)
    text = json.dumps(blocks)
    for t in queries.TASK_TYPES:
        assert t in text
    assert "Launches*\\n17" in text
    assert "churned (drop-out): 3" in text
    assert "Asha: 2" in text and "Ravi: 1" in text


def test_stuck_list_truncates_with_more_marker():
    blocks = build_blocks(_data(stuck_count=20), stuck_after_days=7, stuck_list_limit=5)
    text = json.dumps(blocks)
    assert "and 15 more" in text
    assert text.count("since meta") == 5


def test_no_stuck_sellers_message():
    text = json.dumps(build_blocks(_data(stuck_count=0), 7, 15))
    assert "No sellers stuck" in text


def test_blocks_within_slack_limits():
    blocks = build_blocks(_data(stuck_count=200), 7, 50)
    assert len(blocks) <= 50
    for b in blocks:
        if b["type"] == "section" and "text" in b:
            assert len(b["text"]["text"]) <= 3000


def test_fallback_text():
    assert fallback_text(_data()) == "Onboarding digest 06 Oct: 17 launches, 3 sellers stuck meta→FT"
