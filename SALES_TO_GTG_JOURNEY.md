# Sales → GTG: Seller Communication Journey

---

## Entry Point: Ticket Created (Sale Closed)

`ob_ticket` created → Welcome WA + Email sent → CAGD call scheduled

---

## CAGD Call

```
Ticket Created
        │
        ▼
   CAGD Call
        │
        ├──── ANSWERED ────────────────────────────────────────┐
        │                                                       │
        │              ┌── Docs Received ──→ [MSG A1]          │
        │              │   → Push further process              │
        │              │                                        │
        │              └── No Docs Received ──→ [MSG A2]       │
        │                  (discussed on call, chat link sent)  │
        │                        │                             │
        │                        ├── Docs received later       │
        │                        │   → [MSG A1] further process│
        │                        └── Still no docs             │
        │                            → Escalate (3-day rule)   │
        │                                                       │
        └──── UNANSWERED ──→ [MSG B1] ────────────────────────┘
             (missed call +      │
              next sched call    │
              + chat link)       ├── Docs NOT Received ──→ [MSG B2]
                                 │   → Share docs requirement
                                 │         │
                                 │         ├── Docs received → [MSG A1]
                                 │         └── Still no docs  → Escalate
                                 │
                                 └── Docs Received ──→ [MSG A1]
                                     → Push further process
```

---

## Messages

---

### MSG A1 — Call Answered + Docs Received → Push Further Process

**Channel:** WhatsApp
**Trigger:** CAGD call completed AND docs confirmed received

---

> Hi [Name]! 🙌 Great connecting with you today.
>
> Your documents are in — we're verifying them and you'll hear from us within 24 hours.
>
> While that's underway, here's what's coming up next in your setup:
>
> 📦 **Step 1 — Catalogue:** Upload your products (we can do this for you — just send photos + prices in this chat)
> 📱 **Step 2 — Meta Setup:** Connect your Facebook Business account (~20 min, we'll guide you)
> 💳 **Step 3 — Fund Transfer:** One-time ad budget activation
> ✅ **Step 4 — QC & Go Live!**
>
> Your next call with [Manager Name] is on **[Date] at [Time]**.
> For anything in between — reply here anytime. 👇

---

### MSG A2 — Call Answered + No Docs Received (Discussed on Call)

**Channel:** WhatsApp
**Trigger:** CAGD call completed, docs discussed on call but not yet shared

---

> Hi [Name]! Thanks for the call today 😊
>
> As we discussed — we need these 3 documents to move your setup forward:
>
> 1️⃣ **Aadhaar Card** — front + back photo
> 2️⃣ **PAN Card** — photo of the card
> 3️⃣ **Bank Passbook or Cancelled Cheque** — showing your account number
>
> Just send the photos directly in this chat — usually takes 5–10 minutes and you're done!
>
> For any questions, use this chat or reach us at: [Chat Link / WhatsApp number]
>
> Once we receive your docs, we'll move immediately to the next step 🚀

---

**Follow-up if no docs after 48h:**

> Hi [Name] 👋 Just checking in — we're still waiting on your documents.
> Once you share them, your store moves to the next step within 24 hours.
> Need help? Reply YES and we'll assist right away.

---

### MSG B1 — Call Unanswered

**Channel:** WhatsApp
**Trigger:** CAGD call attempted, no answer

---

> Hi [Name], we tried calling you just now but couldn't connect — no worries!
>
> Your onboarding is moving along. Here's what you should know:
>
> 📞 **Next scheduled call:** [Date] at [Time] with [Manager Name]
>
> **Can't wait?** You can reach us anytime:
> 💬 Reply to this chat
> 🔗 Chat link: [link]
> 📱 Call us: [number]
>
> We'll speak soon!

---

### MSG B2 — Call Unanswered + No Docs Received

**Channel:** WhatsApp
**Trigger:** After MSG B1 sent, docs have not been received

---

> Hi [Name] 👋 While we wait for our next call, here's one thing you can get started on right now:
>
> We need these 3 documents to set up your store:
>
> 1️⃣ **Aadhaar Card** — front + back photo
> 2️⃣ **PAN Card** — photo of the card
> 3️⃣ **Bank Passbook or Cancelled Cheque**
>
> You can send the photos directly here in this chat — it takes about 10 minutes and gets your setup moving even before our next call!
>
> For any questions: [Chat Link]

---

**If docs arrive after MSG B2 → send MSG A1** (further process message)
**If no docs after 3 days → escalation call (standard 3-day rule)**

---

## Decision Logic Summary

| CAGD Call | Docs Status | Message Sent | Next Step |
|---|---|---|---|
| Answered | Received | MSG A1 | Further process (Catalogue) |
| Answered | Not received | MSG A2 | Wait for docs → on receipt, MSG A1 |
| Unanswered | — | MSG B1 | Check docs status |
| Unanswered | Not received | MSG B1 + MSG B2 | Wait for docs → on receipt, MSG A1 |
| Unanswered | Received | MSG B1 + MSG A1 | Further process (Catalogue) |

---

## Escalation (if docs still not received after 3 days from any branch)

**Day +3 (from CAGD task open):**
- Outbound call to unblock
- If unanswered: WA final nudge + SMS

**Day +5 with no docs:**
- Flag to manager → `at_risk` in ob_tasks

**Day +20 with no activity:**
- `dormant` → `churn_seller_callback` task created

---

*Branch: claude/customer-journey-plan-jt6fwd*
