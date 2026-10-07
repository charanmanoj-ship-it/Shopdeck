import json
from datetime import date, datetime

import pytest
from slack_sdk.errors import SlackApiError
from slack_sdk.web import SlackResponse

from shopdeck_bot.delivery import build_admin_report_blocks, deliver_poc_dms
from shopdeck_bot.digest import StuckSeller, group_by_email

AS_OF = date(2026, 10, 7)
ADMIN = "U_ADMIN"


def _err(code):
    resp = SlackResponse(client=None, http_verb="POST", api_url="", req_args={},
                         data={"ok": False, "error": code}, headers={}, status_code=200)
    return SlackApiError(code, resp)


class FakeSlack:
    def __init__(self, directory, fail_post_for=()):
        self.directory = directory  # email -> slack user id
        self.fail_post_for = set(fail_post_for)  # slack user ids whose DM send fails
        self.posts = []  # (channel, text, blocks)
        self.opened = []

    def users_lookupByEmail(self, email):
        if email not in self.directory:
            raise _err("users_not_found")
        return {"user": {"id": self.directory[email]}}

    def conversations_open(self, users):
        self.opened.append(users)
        return {"channel": {"id": f"D_{users}"}}

    def chat_postMessage(self, channel, text, blocks=None):
        if channel.removeprefix("D_") in self.fail_post_for:
            raise _err("cannot_dm_bot")
        self.posts.append((channel, text, blocks))


def s(seller_id, poc, email, days=10):
    return StuckSeller(seller_id, datetime(2026, 9, 27), days, poc, email, "ticket")


STUCK = [
    s("A1", "Asha", "asha@shopdeck.com", 12),
    s("A2", "Asha", "Asha@ShopDeck.com ", 9),  # case/whitespace must still group with A1
    s("R1", "Ravi", "ravi@shopdeck.com", 15),
    s("N1", "Nobody", "gone@shopdeck.com", 20),  # not in Slack
    s("U1", "(unassigned)", None, 8),  # no POC at all
]
DIRECTORY = {"asha@shopdeck.com": "U_ASHA", "ravi@shopdeck.com": "U_RAVI"}


def test_group_by_email_normalises_and_separates_unassigned():
    by_email, no_email = group_by_email(STUCK)
    assert [x.seller_id for x in by_email["asha@shopdeck.com"]] == ["A1", "A2"]
    assert [x.seller_id for x in no_email] == ["U1"]


def test_each_poc_gets_only_their_own_sellers():
    slack = FakeSlack(DIRECTORY)
    report = deliver_poc_dms(slack, STUCK, AS_OF, 7, 15, ADMIN, dry_run=False)

    dms = {ch: json.dumps(blocks) for ch, _, blocks in slack.posts}
    assert set(dms) == {"D_U_ASHA", "D_U_RAVI"}
    assert "A1" in dms["D_U_ASHA"] and "A2" in dms["D_U_ASHA"] and "R1" not in dms["D_U_ASHA"]
    assert "R1" in dms["D_U_RAVI"] and "A1" not in dms["D_U_RAVI"]
    # oldest first within a DM
    assert dms["D_U_ASHA"].index("A1") < dms["D_U_ASHA"].index("A2")
    assert sorted(report.dms_sent) == [("Asha", 2), ("Ravi", 1)]


def test_unroutable_sellers_are_never_dropped():
    report = deliver_poc_dms(FakeSlack(DIRECTORY), STUCK, AS_OF, 7, 15, ADMIN, dry_run=False)
    assert {x.seller_id for x in report.unrouted} == {"N1", "U1"}
    assert report.not_in_slack == [("Nobody", "gone@shopdeck.com", 1)]
    assert report.sellers_delivered + len(report.unrouted) == len(STUCK)


def test_send_failure_moves_sellers_to_unrouted_and_continues():
    slack = FakeSlack(DIRECTORY, fail_post_for={"U_ASHA"})
    report = deliver_poc_dms(slack, STUCK, AS_OF, 7, 15, ADMIN, dry_run=False)
    assert report.send_failed == [("Asha", "cannot_dm_bot", 2)]
    assert report.dms_sent == [("Ravi", 1)]  # Ravi still got his DM
    assert {"A1", "A2"} <= {x.seller_id for x in report.unrouted}


def test_dry_run_sends_nothing_to_pocs():
    slack = FakeSlack(DIRECTORY)
    report = deliver_poc_dms(slack, STUCK, AS_OF, 7, 15, ADMIN, dry_run=True)
    assert slack.opened == []
    assert {ch for ch, _, _ in slack.posts} == {ADMIN}
    assert len(slack.posts) == 2
    assert "Dry run" in json.dumps(slack.posts[0][2])
    assert report.dry_run and len(report.dms_sent) == 2


def test_admin_report_lists_problems_and_unrouted_sellers():
    report = deliver_poc_dms(FakeSlack(DIRECTORY), STUCK, AS_OF, 7, 15, ADMIN, dry_run=False)
    text = json.dumps(build_admin_report_blocks(report, AS_OF, 15))
    assert "2 POCs messaged" in text and "3/5 stuck sellers delivered" in text
    assert "gone@shopdeck.com" in text
    assert "N1" in text and "U1" in text and "need a manual owner" in text


def test_admin_report_when_all_clean():
    report = deliver_poc_dms(FakeSlack(DIRECTORY), [], AS_OF, 7, 15, ADMIN, dry_run=False)
    blocks = build_admin_report_blocks(report, AS_OF, 15)
    assert len(blocks) == 1 and "0 POCs messaged" in json.dumps(blocks)


def test_unexpected_lookup_error_is_reported_not_raised():
    class Broken(FakeSlack):
        def users_lookupByEmail(self, email):
            raise _err("missing_scope")

    report = deliver_poc_dms(Broken({}), STUCK[:1], AS_OF, 7, 15, ADMIN, dry_run=False)
    assert report.send_failed == [("Asha", "missing_scope", 1)]
    assert [x.seller_id for x in report.unrouted] == ["A1"]
