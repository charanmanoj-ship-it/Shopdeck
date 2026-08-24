#!/usr/bin/env python3
"""
Seller Journey Analyzer  —  Sub-agent architecture

Traces a seller's full funnel from Sales → P0 CAGD → KYC/Docs → Catalog → GTG
and identifies exactly where they are stuck + recommended action.

Usage:
  python seller_journey_analyzer.py <seller_id>
  python seller_journey_analyzer.py <seller_id1> <seller_id2> ...
  python seller_journey_analyzer.py --file seller_ids.txt
  python seller_journey_analyzer.py <seller_id> --json

Requirements:
  pip install google-cloud-bigquery
  Set GOOGLE_APPLICATION_CREDENTIALS (service account) or use gcloud ADC.
"""

import sys
import json
import argparse
from datetime import date
from typing import Optional
from dataclasses import dataclass, field, asdict

try:
    from google.cloud import bigquery
except ImportError:
    print("ERROR: google-cloud-bigquery not installed.")
    print("  Run: pip install google-cloud-bigquery")
    sys.exit(1)

PROJECT = "blitzscale-prod-project"

# ── Funnel definition (Sales → P0 CAGD → KYC/Docs → Catalog → GTG) ───────────
# Each entry: (task_type_in_ob_tasks, display_label)
# KYC/Docs doesn't have its own task type — it's a milestone tracked via
# CAGD dispositions / docs-related task types. We detect it from dispositions.
FUNNEL = [
    ("cagd",              "P0 CAGD"),
    ("poc_intro",         "KYC / Docs"),        # docs/intro often recorded here
    ("catalogue_config",  "Catalog Upload"),
    ("meta_setup",        "Meta Setup"),
    ("fund_transfer",     "Fund Transfer"),
    ("qc_check",          "QC Check"),
    ("gtg",               "GTG"),
]
FUNNEL_TYPES  = [f[0] for f in FUNNEL]
FUNNEL_LABELS = dict(FUNNEL)

# Dispositions that signal KYC/Docs received within a CAGD task
DOCS_RECEIVED_DISPOSITIONS = {
    "kyc_received", "docs_received", "documents_received",
    "kyc_submitted", "documents_submitted",
}


# ─────────────────────────────────────────────────────────────────────────────
# Data classes returned by each sub-agent
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class SellerIdentity:
    seller_id:   str
    seller_name: str
    website:     Optional[str]
    ticket_id:   Optional[str]
    dos:         Optional[date]          # Date of Sale = first ticket.created_at


@dataclass
class ConnectInfo:
    first_call_date:    Optional[date]
    first_connect_date: Optional[date]   # first OUTBOUND CONNECTED
    total_outbound:     int
    total_connects:     int
    connect_bucket:     str              # never_called / rnr / connected_d0 / …


@dataclass
class TaskInfo:
    task_id:             str
    task_type:           str
    status:              str
    disposition:         Optional[str]
    disposition_reasons: Optional[str]
    created_date:        Optional[date]
    completed_date:      Optional[date]
    remarks:             Optional[str]
    last_changed_by:     Optional[str]


@dataclass
class FunnelProgress:
    """Which funnel stages are completed, open, or missing."""
    dos:              Optional[date]
    stages_completed: list[str]          # task types with a completed_date
    stages_open:      list[str]          # task types created but not completed
    stages_missing:   list[str]          # not yet created
    docs_received:    bool               # KYC/docs milestone from disposition
    last_stage_done:  Optional[str]      # furthest completed task type
    last_stage_date:  Optional[date]


@dataclass
class ChurnStatus:
    status:                   str        # Live / Active / At risk / Churned / Paused / Dormant
    churn_reason:             Optional[str]
    last_active_date:         Optional[date]
    days_since_last_activity: Optional[int]
    has_inflight_callback:    bool


@dataclass
class StuckPoint:
    stage:               str
    detail:              str
    days_stuck:          Optional[int]
    recommended_action:  str


# ─────────────────────────────────────────────────────────────────────────────
# Shared BigQuery helper
# ─────────────────────────────────────────────────────────────────────────────

def _run_query(client: bigquery.Client, sql: str, seller_id: str):
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("seller_id", "STRING", seller_id)
        ]
    )
    return list(client.query(sql, job_config=job_config).result())


# ─────────────────────────────────────────────────────────────────────────────
# Sub-Agent 1 — Identity & Ticket
# ─────────────────────────────────────────────────────────────────────────────

class IdentityAgent:
    """Resolves seller name, website, Date of Sale, and onboarding ticket."""

    SQL = """
    SELECT
      s._id                                              AS seller_id,
      CONCAT(s.first_name, ' ', s.last_name)            AS seller_name,
      s.custom_domain                                    AS website,
      t.id                                               AS ticket_id,
      DATE(t.created_at, 'Asia/Kolkata')                AS dos
    FROM `blitzscale-prod-project.nushop.sellers` s
    LEFT JOIN `blitzscale-prod-project.nushop.ob_tickets` t
      ON t.seller_id = s._id
    WHERE s._id = @seller_id
    ORDER BY t.created_at ASC
    LIMIT 1
    """

    def run(self, client: bigquery.Client, seller_id: str) -> SellerIdentity:
        rows = _run_query(client, self.SQL, seller_id)
        if not rows:
            return SellerIdentity(seller_id=seller_id, seller_name="Unknown",
                                   website=None, ticket_id=None, dos=None)
        r = rows[0]
        return SellerIdentity(
            seller_id=r.seller_id,
            seller_name=r.seller_name or "Unknown",
            website=r.website,
            ticket_id=r.ticket_id,
            dos=r.dos,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Sub-Agent 2 — Connect History  (Sales → P0 Connect)
# ─────────────────────────────────────────────────────────────────────────────

class ConnectAgent:
    """
    Checks Exotel call history to determine if/when the seller was first
    reached by the calling team and computes the connect-speed bucket.
    """

    SQL = """
    SELECT
      DATE(ec.created_at, 'Asia/Kolkata')  AS call_date,
      LOWER(ecd.call_type)                 AS call_type,
      UPPER(ecd.status)                    AS call_status
    FROM `blitzscale-prod-project.nushop.exotel_calls` ec
    JOIN `blitzscale-prod-project.nushop.ob_tasks` ot
      ON ot.id = ec.entity_id
    JOIN `blitzscale-prod-project.nushop.exotel_call_details` ecd
      ON ecd.sid = ec.id
    WHERE ot.seller_id = @seller_id
    ORDER BY ec.created_at ASC
    """

    def run(self, client: bigquery.Client, seller_id: str,
            dos: Optional[date]) -> ConnectInfo:
        rows = _run_query(client, self.SQL, seller_id)

        outbound  = [r for r in rows if r.call_type == "outbound"]
        connects  = [r for r in outbound if r.call_status == "CONNECTED"]

        first_call    = outbound[0].call_date if outbound else None
        first_connect = connects[0].call_date if connects else None

        if not outbound:
            bucket = "never_called"
        elif not connects:
            bucket = "called_never_connected_rnr"
        elif dos and first_connect:
            d = (first_connect - dos).days
            if   d <  0: bucket = "connected_before_dos"
            elif d == 0: bucket = "connected_d0"
            elif d == 1: bucket = "connected_d1"
            elif d == 2: bucket = "connected_d2"
            elif d == 3: bucket = "connected_d3"
            else:        bucket = "connected_after_3d"
        else:
            bucket = "connected"

        return ConnectInfo(
            first_call_date=first_call,
            first_connect_date=first_connect,
            total_outbound=len(outbound),
            total_connects=len(connects),
            connect_bucket=bucket,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Sub-Agent 3 — Onboarding Tasks  (full timeline)
# ─────────────────────────────────────────────────────────────────────────────

class TasksAgent:
    """Fetches every ob_task for the seller, ordered chronologically."""

    SQL = """
    SELECT
      id,
      type,
      COALESCE(status, '') AS status,
      disposition,
      disposition_reasons,
      remarks,
      last_changed_by,
      DATE(created_at,   'Asia/Kolkata') AS created_date,
      DATE(completed_at, 'Asia/Kolkata') AS completed_date
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE seller_id = @seller_id
    ORDER BY created_at ASC
    """

    def run(self, client: bigquery.Client, seller_id: str) -> list[TaskInfo]:
        rows = _run_query(client, self.SQL, seller_id)
        return [
            TaskInfo(
                task_id=r.id,
                task_type=r.type,
                status=r.status,
                disposition=r.disposition,
                disposition_reasons=r.disposition_reasons,
                created_date=r.created_date,
                completed_date=r.completed_date,
                remarks=r.remarks,
                last_changed_by=r.last_changed_by,
            )
            for r in rows
        ]


# ─────────────────────────────────────────────────────────────────────────────
# Sub-Agent 4 — Funnel Progress
# Maps tasks onto the funnel: Sales → P0 CAGD → KYC/Docs → Catalog → GTG
# ─────────────────────────────────────────────────────────────────────────────

class FunnelProgressAgent:
    """
    Given the full task list, classifies each funnel stage as:
      completed | open (created, not done) | missing (not started)
    Also detects whether KYC/Docs milestone was reached from dispositions.
    """

    def run(self, dos: Optional[date], tasks: list[TaskInfo]) -> FunnelProgress:
        completed = set()
        open_stages = set()
        last_stage_done = None
        last_stage_date = None
        docs_received = False

        # Scan tasks once
        for t in tasks:
            if t.task_type in FUNNEL_TYPES:
                if t.completed_date:
                    completed.add(t.task_type)
                    # track furthest completed stage by funnel order
                    idx = FUNNEL_TYPES.index(t.task_type)
                    if last_stage_done is None or idx >= FUNNEL_TYPES.index(last_stage_done):
                        last_stage_done = t.task_type
                        last_stage_date = t.completed_date
                else:
                    open_stages.add(t.task_type)

            # KYC/Docs milestone: check CAGD (or any task) for doc-received dispositions
            disp = (t.disposition or "") + " " + (t.disposition_reasons or "")
            if any(d in disp.lower() for d in DOCS_RECEIVED_DISPOSITIONS):
                docs_received = True

        missing = [s for s in FUNNEL_TYPES if s not in completed and s not in open_stages]

        return FunnelProgress(
            dos=dos,
            stages_completed=sorted(completed, key=lambda s: FUNNEL_TYPES.index(s)),
            stages_open=sorted(open_stages, key=lambda s: FUNNEL_TYPES.index(s)),
            stages_missing=missing,
            docs_received=docs_received,
            last_stage_done=last_stage_done,
            last_stage_date=last_stage_date,
        )


# ─────────────────────────────────────────────────────────────────────────────
# Sub-Agent 5 — Churn Status  (8-level model)
# ─────────────────────────────────────────────────────────────────────────────

class ChurnStatusAgent:
    """
    Applies the verified 8-level churn model to determine the seller's
    current retention status from ob_tasks signals.
    """

    SQL = """
    SELECT
      MAX(IF(disposition IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                             'not_in_shopdeck_criteria','photoshoot_not_available'),
             COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
             NULL))                                    AS last_drop_date,
      MAX(IF(disposition = 'seller_wants_to_drop_out',
             COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
             NULL))                                    AS dropout_date,
      MAX(IF(disposition IN ('asked_to_drop_the_lead','not_in_shopdeck_criteria',
                             'photoshoot_not_available'),
             COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
             NULL))                                    AS last_soft_drop_date,
      MAX(IF(disposition = 'seller_wants_to_pause',
             COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
             NULL))                                    AS last_pause_date,
      MAX(IF(LOWER(type) = 'qc_check' AND LOWER(disposition) = 'qc_completed_and_okay',
             COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
             NULL))                                    AS qc_completed_date,
      MAX(IF(type = 'churn_seller_callback'
               AND disposition IN ('seller_wants_to_continue','seller_resumed'),
             COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
             NULL))                                    AS last_retained_date,
      MAX(IF(type = 'churn_seller_callback',
             COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
             NULL))                                    AS last_cb_date,
      LOGICAL_OR(
        type = 'churn_seller_callback'
        AND (disposition IS NULL
             OR disposition IN ('seller_did_not_pick_up_the_call',
                                'seller_wants_to_call_later',
                                'schedule_account_health_call'))
        AND COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata'))
            >= DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 20 DAY)
      )                                                AS has_inflight_cb,
      MAX(
        IF(type NOT IN ('churn_seller_callback','callback')
           AND (disposition IS NULL
                OR disposition NOT IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                                       'not_in_shopdeck_criteria','photoshoot_not_available')),
           DATE(created_at,'Asia/Kolkata'), NULL)
      )                                                AS last_active_date,
      STRING_AGG(
        DISTINCT IF(disposition IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                                    'not_in_shopdeck_criteria','photoshoot_not_available'),
                    disposition, NULL), ', '
      )                                                AS churn_reason
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE seller_id = @seller_id
    """

    def run(self, client: bigquery.Client, seller_id: str) -> ChurnStatus:
        rows = _run_query(client, self.SQL, seller_id)
        if not rows:
            return ChurnStatus("Unknown", None, None, None, False)

        r = rows[0]
        today = date.today()

        last_active  = r.last_active_date
        last_drop    = r.last_drop_date
        last_pause   = r.last_pause_date
        dropout      = r.dropout_date
        retained     = r.last_retained_date
        soft_drop    = r.last_soft_drop_date
        cb_date      = r.last_cb_date
        inflight     = r.has_inflight_cb
        completion   = r.qc_completed_date

        is_dormant = (last_active is None or
                      (today - last_active).days >= 20)

        if completion and (last_drop is None or completion >= last_drop) \
                      and (last_pause is None or completion >= last_pause):
            status = "Live account"
        elif retained and (last_drop is None or retained >= last_drop) \
                      and (last_pause is None or retained >= last_pause):
            status = "Active"
        elif dropout and (last_pause is None or dropout >= last_pause):
            status = "Churned"
        elif last_pause and (last_drop is None or last_pause >= last_drop):
            status = "Paused"
        elif (soft_drop or cb_date) and (inflight or not is_dormant):
            status = "At risk"
        elif soft_drop or cb_date:
            status = "Churned"
        elif is_dormant:
            status = "Dormant"
        else:
            status = "Active"

        days_silent = (today - last_active).days if last_active else None

        return ChurnStatus(
            status=status,
            churn_reason=r.churn_reason,
            last_active_date=last_active,
            days_since_last_activity=days_silent,
            has_inflight_callback=bool(inflight),
        )


# ─────────────────────────────────────────────────────────────────────────────
# Sub-Agent 6 — Stuck Point Detector
# ─────────────────────────────────────────────────────────────────────────────

class StuckDetectorAgent:
    """
    Synthesizes all sub-agent outputs.
    Returns the exact funnel stage where the seller is stuck
    and a recommended next action.
    """

    def run(self, identity: SellerIdentity, connect: ConnectInfo,
            progress: FunnelProgress, tasks: list[TaskInfo],
            churn: ChurnStatus) -> StuckPoint:

        today = date.today()
        dos = identity.dos
        days_in = (today - dos).days if dos else None

        # ── No ticket found ────────────────────────────────────────────────
        if not dos:
            return StuckPoint("No ticket", "No onboarding ticket found.", None,
                              "Check if seller was onboarded under a different ID.")

        # ── Never called ──────────────────────────────────────────────────
        if connect.connect_bucket == "never_called":
            return StuckPoint(
                stage="Stage 1 — Sales (never called)",
                detail=f"Ticket exists (DOS: {dos}) but seller has never been called. {days_in}d elapsed.",
                days_stuck=days_in,
                recommended_action="Assign to calling team immediately — P0 priority.",
            )

        # ── Called but no connect ─────────────────────────────────────────
        if connect.connect_bucket == "called_never_connected_rnr":
            return StuckPoint(
                stage="Stage 1 — Connect (RNR / no-show)",
                detail=(f"{connect.total_outbound} outbound call(s), zero connects. "
                        f"First call: {connect.first_call_date}. {days_in}d since DOS."),
                days_stuck=days_in,
                recommended_action="Escalate to churn-seller-callback or try alternate number.",
            )

        # ── Connected but no CAGD started ────────────────────────────────
        cagd_tasks = [t for t in tasks if t.task_type == "cagd"]
        if not cagd_tasks:
            days_since_connect = (today - connect.first_connect_date).days if connect.first_connect_date else days_in
            return StuckPoint(
                stage="Stage 2 — P0 CAGD (not started)",
                detail=(f"Connected on {connect.first_connect_date} "
                        f"but CAGD task not yet created. {days_since_connect}d since first connect."),
                days_stuck=days_since_connect,
                recommended_action="Create CAGD task and schedule onboarding session.",
            )

        # ── CAGD open but not completed ───────────────────────────────────
        cagd_done = [t for t in cagd_tasks if t.completed_date]
        cagd_open = [t for t in cagd_tasks if not t.completed_date]
        if not cagd_done:
            days_since = (today - cagd_open[0].created_date).days if cagd_open[0].created_date else days_in
            owner = cagd_open[0].last_changed_by or "unknown"
            return StuckPoint(
                stage="Stage 2 — P0 CAGD (open / in-progress)",
                detail=(f"CAGD created {cagd_open[0].created_date} ({days_since}d ago), "
                        f"not yet completed. Assigned to: {owner}. "
                        f"Disposition: {cagd_open[0].disposition or '—'}."),
                days_stuck=days_since,
                recommended_action="Follow up with OB team to complete CAGD session.",
            )

        # ── CAGD done — check KYC/Docs ───────────────────────────────────
        cagd_complete_date = max(t.completed_date for t in cagd_done)
        if not progress.docs_received:
            # Also check if poc_intro exists (proxy for docs)
            poc_tasks = [t for t in tasks if t.task_type == "poc_intro"]
            poc_done  = [t for t in poc_tasks if t.completed_date]
            if not poc_done:
                days_since = (today - cagd_complete_date).days
                return StuckPoint(
                    stage="Stage 3 — KYC / Docs (not received)",
                    detail=(f"CAGD completed {cagd_complete_date}. "
                            f"KYC/Docs not yet received ({days_since}d elapsed). "
                            f"POC intro: {'open' if poc_tasks else 'not created'}."),
                    days_stuck=days_since,
                    recommended_action="Follow up with seller for KYC documents. Check POC intro task.",
                )

        # Reference date for subsequent stage calculations
        docs_date = cagd_complete_date  # best proxy we have without explicit docs task

        # ── KYC done — check Catalog ──────────────────────────────────────
        cat_tasks = [t for t in tasks if t.task_type == "catalogue_config"]
        cat_done  = [t for t in cat_tasks if t.completed_date]
        cat_open  = [t for t in cat_tasks if not t.completed_date]
        if not cat_done:
            days_since = (today - docs_date).days
            if cat_open:
                owner = cat_open[0].last_changed_by or "unknown"
                detail = (f"Catalog task open since {cat_open[0].created_date}. "
                          f"Owner: {owner}. {days_since}d since KYC completed.")
                action = "Expedite catalog upload — check with catalog team."
            else:
                detail = (f"Catalog task not yet created. {days_since}d since KYC.")
                action = "Create catalogue_config task and assign to catalog team."
            return StuckPoint(
                stage="Stage 4 — Catalog Upload",
                detail=detail, days_stuck=days_since,
                recommended_action=action,
            )

        cat_complete_date = max(t.completed_date for t in cat_done)

        # ── Catalog done — check remaining tasks before GTG ───────────────
        mid_stages = [("meta_setup", "Meta Setup"), ("fund_transfer", "Fund Transfer")]
        for task_type, label in mid_stages:
            ts = [t for t in tasks if t.task_type == task_type]
            done = [t for t in ts if t.completed_date]
            open_ = [t for t in ts if not t.completed_date]
            if not done:
                ref_date = cat_complete_date
                days_since = (today - ref_date).days
                if open_:
                    owner = open_[0].last_changed_by or "unknown"
                    detail = (f"{label} open since {open_[0].created_date}. "
                              f"Owner: {owner}. {days_since}d since catalog.")
                    action = f"Follow up on {label} completion."
                else:
                    detail = f"{label} not started. {days_since}d since catalog."
                    action = f"Create {task_type} task."
                return StuckPoint(
                    stage=f"Stage — {label}",
                    detail=detail, days_stuck=days_since,
                    recommended_action=action,
                )

        # ── Check GTG (final milestone) ───────────────────────────────────
        gtg_tasks = [t for t in tasks if t.task_type == "gtg"]
        gtg_done  = [t for t in gtg_tasks if t.completed_date]
        gtg_open  = [t for t in gtg_tasks if not t.completed_date]

        if gtg_done:
            gtg_date = max(t.completed_date for t in gtg_done)
            if churn.status == "Live account":
                return StuckPoint("Live account",
                                  f"GTG reached {gtg_date}. Seller is live.",
                                  0, "Monitor account health.")
            return StuckPoint(
                stage="Post-GTG — Active",
                detail=f"GTG completed {gtg_date}. Current status: {churn.status}.",
                days_stuck=0,
                recommended_action="Track in post-GTG pipeline (meta, website, go-live).",
            )

        # GTG not yet reached
        ref = cat_complete_date
        days_since = (today - ref).days

        if churn.status in ("Churned", "Paused"):
            reason_str = f"Reason: {churn.churn_reason}." if churn.churn_reason else ""
            return StuckPoint(
                stage=f"Stage 5 — GTG blocked ({churn.status})",
                detail=(f"All pre-GTG steps done but seller is {churn.status}. {reason_str} "
                        f"Last active: {churn.last_active_date}."),
                days_stuck=churn.days_since_last_activity,
                recommended_action="Resolve churn/pause before scheduling GTG.",
            )

        if gtg_open:
            owner = gtg_open[0].last_changed_by or "unknown"
            return StuckPoint(
                stage="Stage 5 — GTG (in-progress)",
                detail=(f"GTG task open since {gtg_open[0].created_date} ({days_since}d). "
                        f"Owner: {owner}."),
                days_stuck=days_since,
                recommended_action="Follow up on GTG completion with OB team.",
            )

        return StuckPoint(
            stage="Stage 5 — GTG (not scheduled)",
            detail=f"Pre-GTG steps complete but GTG task not created. {days_since}d since catalog.",
            days_stuck=days_since,
            recommended_action="Create GTG task and schedule GTG session.",
        )


# ─────────────────────────────────────────────────────────────────────────────
# Orchestrator  —  wires all 6 sub-agents together
# ─────────────────────────────────────────────────────────────────────────────

class SellerJourneyAnalyzer:
    """
    Coordinates sub-agents to produce a full seller journey report.

    Funnel: Sales Lead → P0 CAGD → KYC/Docs → Catalog Upload → [Meta/Fund] → GTG
    """

    def __init__(self):
        self.client  = bigquery.Client(project=PROJECT)
        self._agents = {
            "identity": IdentityAgent(),
            "connect":  ConnectAgent(),
            "tasks":    TasksAgent(),
            "funnel":   FunnelProgressAgent(),
            "churn":    ChurnStatusAgent(),
            "stuck":    StuckDetectorAgent(),
        }

    def analyze(self, seller_id: str) -> dict:
        seller_id = seller_id.strip()
        print(f"\n  Analyzing seller: {seller_id}", file=sys.stderr)

        print("  [1/6] Identity & ticket...", file=sys.stderr)
        identity = self._agents["identity"].run(self.client, seller_id)

        print("  [2/6] Call / connect history...", file=sys.stderr)
        connect = self._agents["connect"].run(self.client, seller_id, identity.dos)

        print("  [3/6] Onboarding tasks timeline...", file=sys.stderr)
        tasks = self._agents["tasks"].run(self.client, seller_id)

        print("  [4/6] Funnel progress mapping...", file=sys.stderr)
        progress = self._agents["funnel"].run(identity.dos, tasks)

        print("  [5/6] Churn status model...", file=sys.stderr)
        churn = self._agents["churn"].run(self.client, seller_id)

        print("  [6/6] Stuck-point detection...", file=sys.stderr)
        stuck = self._agents["stuck"].run(identity, connect, progress, tasks, churn)

        return dict(identity=identity, connect=connect, tasks=tasks,
                    progress=progress, churn=churn, stuck=stuck)

    # ── Report printer ─────────────────────────────────────────────────────

    @staticmethod
    def print_report(result: dict) -> None:
        identity: SellerIdentity  = result["identity"]
        connect:  ConnectInfo     = result["connect"]
        tasks:    list[TaskInfo]  = result["tasks"]
        progress: FunnelProgress  = result["progress"]
        churn:    ChurnStatus     = result["churn"]
        stuck:    StuckPoint      = result["stuck"]

        W = 64
        print(f"\n{'═'*W}")
        print(f"  SELLER JOURNEY REPORT")
        print(f"{'═'*W}")
        print(f"  Seller ID   : {identity.seller_id}")
        print(f"  Name        : {identity.seller_name}")
        print(f"  Website     : {identity.website or '—'}")
        print(f"  DOS         : {identity.dos or 'Unknown'}")
        print(f"  Ticket ID   : {identity.ticket_id or '—'}")

        print(f"\n  ── CONNECT ──────────────────────────────────────────")
        print(f"  Bucket           : {connect.connect_bucket}")
        print(f"  First call       : {connect.first_call_date or '—'}")
        print(f"  First connect    : {connect.first_connect_date or '—'}")
        print(f"  Outbound / Conn  : {connect.total_outbound} calls / {connect.total_connects} connects")

        print(f"\n  ── FUNNEL PROGRESS  (Sales → P0 CAGD → KYC → Catalog → GTG) ─")
        for task_type, label in FUNNEL:
            if task_type in progress.stages_completed:
                marker = "✓"
            elif task_type in progress.stages_open:
                marker = "○"   # in-progress
            else:
                marker = "·"   # not started
            print(f"  {marker}  {label:<22} ({task_type})")
        if progress.docs_received:
            print(f"     KYC/Docs milestone: RECEIVED")

        print(f"\n  ── FULL TASK TIMELINE ───────────────────────────────")
        if tasks:
            core = {f[0] for f in FUNNEL}
            onboarding = [t for t in tasks if t.task_type in core]
            other      = [t for t in tasks if t.task_type not in core]
            for t in onboarding:
                done = f"✓ {t.completed_date}" if t.completed_date else f"○ {t.created_date}"
                disp = f" → {t.disposition}" if t.disposition else ""
                print(f"  {done:28s}  {t.task_type}{disp}")
            if other:
                other_types = ", ".join(sorted({t.task_type for t in other}))
                print(f"  + {len(other)} other task(s): {other_types}")
        else:
            print("  No tasks found.")

        print(f"\n  ── CHURN STATUS ─────────────────────────────────────")
        print(f"  Status           : {churn.status}")
        if churn.churn_reason:
            print(f"  Churn reason     : {churn.churn_reason}")
        print(f"  Last active      : {churn.last_active_date or '—'}")
        if churn.days_since_last_activity is not None:
            print(f"  Days silent      : {churn.days_since_last_activity}d")
        if churn.has_inflight_callback:
            print(f"  In-flight callback: YES")

        print(f"\n  ── WHERE IS SELLER STUCK? ───────────────────────────")
        print(f"  Stage   : {stuck.stage}")
        print(f"  Detail  : {stuck.detail}")
        if stuck.days_stuck is not None:
            print(f"  Stuck   : {stuck.days_stuck}d")
        print(f"  Action  : {stuck.recommended_action}")
        print(f"{'═'*W}\n")

    @staticmethod
    def to_json(result: dict) -> str:
        def default(o):
            if isinstance(o, date): return str(o)
            if hasattr(o, "__dataclass_fields__"): return asdict(o)
            return str(o)
        serializable = {
            k: (asdict(v) if hasattr(v, "__dataclass_fields__")
                else [asdict(i) for i in v] if isinstance(v, list) else v)
            for k, v in result.items()
        }
        return json.dumps(serializable, default=default, indent=2)


# ─────────────────────────────────────────────────────────────────────────────
# CLI entry point
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Seller Journey Analyzer — trace the full Sales→GTG funnel for a seller.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python seller_journey_analyzer.py 69fd7f4f984975bfa22d4014
  python seller_journey_analyzer.py 69fd7f4f984975bfa22d4014 6a0312f8317e68f10e9bbadc
  python seller_journey_analyzer.py --file seller_ids.txt
  python seller_journey_analyzer.py 69fd7f4f984975bfa22d4014 --json
        """
    )
    parser.add_argument("seller_ids", nargs="*", help="One or more seller IDs")
    parser.add_argument("--file", "-f", help="Text file with one seller_id per line")
    parser.add_argument("--json", action="store_true", help="Output machine-readable JSON")
    args = parser.parse_args()

    ids: list[str] = list(args.seller_ids)
    if args.file:
        with open(args.file) as fh:
            ids += [ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")]

    if not ids:
        parser.print_help()
        sys.exit(1)

    analyzer = SellerJourneyAnalyzer()
    results = []

    for sid in ids:
        try:
            result = analyzer.analyze(sid)
            if args.json:
                results.append(result)
            else:
                analyzer.print_report(result)
        except Exception as exc:
            print(f"\nERROR analyzing {sid}: {exc}", file=sys.stderr)
            import traceback; traceback.print_exc(file=sys.stderr)

    if args.json:
        print(analyzer.to_json(results[0]) if len(results) == 1
              else json.dumps([json.loads(analyzer.to_json(r)) for r in results], indent=2))


if __name__ == "__main__":
    main()
