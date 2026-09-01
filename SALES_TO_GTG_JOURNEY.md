# Sales → GTG: Seller Communication Journey

Full touchpoint map for every case — from sale closed to store going live.

---

## Overview

| Stage | Window | Primary Channel | Key Decision |
|---|---|---|---|
| 1. Welcome | T+0 (within 30 min) | WhatsApp + Email | Sale time (before/after 1pm) |
| 2. First Call | T+2h or next morning | Outbound Call | Answered / Unanswered |
| 3. Docs Collection | Day 2–5 | WhatsApp → Email | Docs received / Not received |
| 4. Catalogue Upload | Day 5–10 | WhatsApp | Uploaded / Stuck |
| 5. WD / Meta / Domain | Day 10–15 | WhatsApp + Call | Connected / Blocked |
| 6. Fund Transfer | Day 15–20 | WhatsApp + Call | Paid / Objection |
| 7. DTR / QC | Day 20–25 | WhatsApp | Passed / Issues |
| 8. GTG | Day 25–30 | WhatsApp + Email | Live! |

**Escalation Rule (all stages):** No response for 3 days → outbound call. No response for 5 days → flag to manager.

---

## Stage 1: Welcome — Immediately After Sale

**Trigger:** `ob_ticket` created (Date of Sale recorded)

### 1A — WhatsApp to Seller (within 30 min of sale)

**If sale before 1:00 PM (Mon–Fri):**
> Hi [Name]! 👋 Welcome to Shopdeck — we're excited to have you onboard!
> Your store setup starts today. Here's what to expect:
>
> ✅ Step 1 — Intro call with your onboarding manager (today between [Time Slot])
> ✅ Step 2 — Share 3 documents (takes ~10 min)
> ✅ Step 3 — Upload your products
> ✅ Step 4 — Go LIVE in ~2–3 weeks!
>
> Your manager [Manager Name] will call you shortly. Keep your phone handy!

**If sale after 1:00 PM OR on Saturday/Sunday:**
> Hi [Name]! 👋 Welcome to Shopdeck!
> We've received your registration and your store setup is confirmed.
>
> Your onboarding manager [Manager Name] will call you **tomorrow morning between 10–11 AM**.
>
> Until then — no action needed from your side. We'll walk you through everything on the call!

**If phone number not available in system:**
→ Trigger internal alert to sales rep: "Phone number missing for [Seller ID] — collect before first call"
→ Hold all messages until number confirmed

---

### 1B — Email to Seller (within 1 hour of sale)

**Subject:** Your Shopdeck store is being set up 🚀

> Hi [Name],
>
> Welcome to Shopdeck! We're setting up your store and your onboarding manager [Manager Name] will be in touch shortly.
>
> **What you'll need for your onboarding call:**
> 1. Aadhaar Card (front + back)
> 2. PAN Card
> 3. Bank passbook or cancelled cheque
> 4. 10–15 product photos (if ready)
>
> **Your onboarding journey:**
> → Intro Call → Documents → Catalogue → Store Setup → Go Live
>
> Expected timeline: **2–3 weeks from today.**
>
> Any questions? Reply to this email or WhatsApp us at [number].
>
> — Team Shopdeck

---

## Stage 2: First Call

**Trigger:** Manager initiates first call per schedule from Stage 1

### CASE A: Call Answered ✅

**Immediately after call — WhatsApp:**
> Hi [Name]! Great connecting with you today 🙌
>
> Quick summary of what we discussed:
> • [Discussion point 1]
> • [Discussion point 2]
> • Next step: [specific action required from seller]
>
> Your next follow-up with [Manager Name] is on **[Date] at [Time]**.
>
> For any questions before then — just reply here or use this chat link: [link]
> Callback number: [number]

**Email (post-call summary):**

Subject: Your Shopdeck onboarding — next steps

> Hi [Name],
>
> Thanks for the call today! Here's a summary:
>
> **Discussed:**
> - [point]
> - [point]
>
> **Your next steps:**
> 1. [Action 1 — e.g., share documents]
> 2. [Action 2]
>
> **Next call:** [Date & Time]
>
> Need to reschedule or have questions? Reply here or WhatsApp [Manager Name] at [number].

---

### CASE B: Call Unanswered — Attempt 1

**WhatsApp (immediately after unanswered call):**
> Hi [Name], we tried calling you just now but couldn't connect.
>
> No worries — reply here with a time that works for you and we'll call right back! ⏰
> Or call us directly: [number]

**Email (within 30 min of missed call):**

Subject: We tried calling — your Shopdeck setup is waiting

> Hi [Name],
>
> We tried reaching you for your onboarding call but couldn't connect.
>
> **To get started while you wait for our next call:**
> 1. Keep these documents ready: Aadhaar, PAN, bank doc
> 2. Download the Shopdeck app: [App Link] (Registration ID: [Seller ID])
>
> We'll try calling again in a few hours. Or reply to this email with a preferred time.

---

### CASE C: Call Unanswered — Attempt 2 (2–3 hours later)

**WhatsApp:**
> Hi [Name] 👋 We tried reaching you again. Your onboarding is ready to begin whenever you are!
>
> Reply **CALL ME** and we'll reach out within the next 30 minutes.
> Or pick a time here: [Calendly / form link]

**Log in ob_tasks:** disposition = `rnr_attempt_2`

---

### CASE D: Call Unanswered — Attempt 3 (next morning)

**WhatsApp:**
> Hi [Name], we've been trying to reach you to kick off your store setup.
> We don't want you to lose your spot! 🏪
>
> Please call us at [number] or reply here to schedule your intro call.

**Internal flag:** Notify sales manager if still no response after attempt 3.
**ob_tasks:** disposition = `rnr_attempt_3` → create `callback` task

---

## Stage 3: Docs Collection

**Trigger:** CAGD task completed → KYC/Docs task opens

### 3A — Initial Request

**WhatsApp:**
> Hi [Name]! Great call ✅ Now for the fastest route to going live — we need 3 documents:
>
> 1️⃣ Aadhaar Card (front + back photo)
> 2️⃣ PAN Card
> 3️⃣ Bank passbook or cancelled cheque
>
> Just send the photos directly in this chat. Usually takes 10 minutes!

---

### 3B — Docs Not Received (48 hours later)

**WhatsApp:**
> Hi [Name], just a reminder — we're still waiting on your documents to move your store setup forward.
>
> Once we receive them, your store goes into the next stage within 24 hours 📦
>
> Stuck on something? Reply YES and we'll help you right away.

**SMS (parallel, if WA undelivered):**
> Shopdeck: Your KYC docs are pending. Share Aadhaar, PAN & bank doc on WhatsApp: [number]. Store launch on hold until received. Call: [number]

---

### 3C — Docs Not Received (Day +3) → Outbound Call

Agent calls to unblock. Common issues to resolve on call:
- No GST → proceed without, note in ob_tasks
- Bank doc format unclear → accept passbook screenshot
- PAN not available → collect later, proceed with Aadhaar only for now

**Post-call WhatsApp (if issue resolved):**
> Thanks [Name]! Got it sorted. Please share [specific doc] when you can and we'll move ahead immediately 🚀

---

### 3D — Docs Received ✅

**WhatsApp:**
> Documents received! ✅ Thank you, [Name].
> Our team is verifying them now — this takes up to 24 hours.
> Next step: we'll ask you to upload your product catalogue. Get your product photos and prices ready!

---

## Stage 4: Catalogue Upload

**Trigger:** `catalogue_config` task opens

### 4A — Initial Message

**WhatsApp:**
> Time to build your store! 🛍️
>
> You can add products in 2 ways:
>
> **Option A (Easy):** Send us your product photos + prices directly in this chat — our team will upload them for you.
>
> **Option B (Self-upload):** Use our Excel template: [link] — fill in product name, price, description, and images.
>
> Most sellers go with Option A. Want to try that? Just drop your first product photo here!

**Email (Day +1):**

Subject: Add your products — here's how (+ free template)

> Hi [Name],
>
> Your store is ready for products! Here's what you need to know:
>
> ✅ **Minimum to launch:** 15 products
> 📈 **Tip:** Stores with 20+ products see 3× more weekly orders
>
> [Download Excel Template]
>
> **Photo guidelines:**
> - Plain/white background preferred
> - Good lighting, no blurry images
> - Show the product clearly (front view)
>
> Or just WhatsApp us the photos and we'll handle the rest.

---

### 4B — Progress Check-in (Day +3, <10 products uploaded)

**WhatsApp:**
> Hi [Name] 👋 Your store has [X] products so far — great start!
>
> Aim for at least 15 before we can go live. You're [15-X] away.
>
> Want us to add the remaining products for you? Just send the photos here and we'll take care of it today.

---

### 4C — Stuck / No Progress (Day +5)

**WhatsApp:**
> Hi [Name], your catalogue is still incomplete and we want to get you live!
>
> Here's the easiest path: send us ANY 15 product photos right now — name + price for each. We'll have your store catalogue ready within 24 hours.

**Outbound Call:** Agent offers concierge upload — complete it live over call if needed.

---

### 4D — Catalogue Complete ✅

**WhatsApp:**
> Your catalogue is live on your store — [X] products added! 🎉
>
> Next step: connecting your Facebook/Meta account so your ads can reach customers.
> This takes ~20 minutes. We'll guide you through it on the next call.

---

## Stage 5: WD / Meta / Domain Setup

**Trigger:** `meta_setup` task opens

### 5A — Initial Message

**WhatsApp:**
> Almost there, [Name]! One important step — connecting your Facebook Business account.
>
> This lets Shopdeck run ads for your store and bring you customers 📣
>
> Want to do it on a quick call with us? We'll screen-share and do it together in ~20 minutes.
> Reply **YES** to schedule.

---

### 5B — No Action (Day +1) → Step-by-Step Guide

**WhatsApp:**
> Here's the 5-step guide to connect Facebook:
>
> 1️⃣ Go to [link]
> 2️⃣ Click "Connect Facebook"
> 3️⃣ Log in with your personal Facebook account
> 4️⃣ Select your Business Page
> 5️⃣ Approve the permissions
>
> Stuck at any step? Reply with the step number and we'll fix it right away.

---

### 5C — Blocker: No Facebook Business Page

**WhatsApp:**
> No worries! We'll create your Facebook Business Page first — it only takes 5 minutes.
>
> Can we schedule a quick call for this? Reply **CALL ME** or pick a time: [link]

---

### 5D — No Response (Day +3) → Outbound Call

Agent does a screen-share call to complete Meta setup live. This is the highest-friction stage — live assist is mandatory if seller is unresponsive.

**ob_tasks:** log disposition as `meta_setup_call_done` or `meta_setup_blocked`

---

### 5E — Meta Setup Complete ✅

**WhatsApp:**
> Facebook connected successfully! ✅
>
> Your store is almost ready. One more step: the initial fund transfer to activate your ad campaigns.
> [Manager Name] will walk you through this on your next call.

---

## Stage 6: Fund Transfer

**Trigger:** `fund_transfer` task opens

### 6A — Initial Message

**WhatsApp:**
> Hi [Name]! Your store setup is nearly complete 🏁
>
> Last financial step: transfer ₹[Amount] to activate your ad budget.
>
> 📌 **Why this transfer?**
> This covers your first [X] days of ad spend. You earn it back through delivered orders — it's not a fee, it's your ad investment.
>
> 🏦 **Transfer details:**
> Account Name: [Name]
> Account No: [Number]
> IFSC: [Code]
> Reference: [Seller ID]
>
> Once transferred, share the UTR or screenshot here and we'll confirm within 2 hours.

---

### 6B — 24h No Transfer

**WhatsApp:**
> Hi [Name], just checking in on the transfer. Your store is ready and waiting to go live!
>
> Any questions about the payment? Reply here — we'll clear it up immediately.

---

### 6C — Objection / Hesitation → Outbound Call (Day +2)

Agent addresses common objections:

| Objection | Response |
|---|---|
| "Why pay before orders?" | "It's your ad spend — not a platform fee. Every rupee goes into bringing you customers." |
| "I need more time" | "We can hold your slot for [X] days. After that, re-onboarding needed." |
| "Can I pay less first?" | Escalate to finance — partial activation may be possible |
| "I want to drop out" | Log `seller_wants_to_drop_out` in ob_tasks → churn flow |

**ob_tasks:** disposition = `fund_transfer_objection_handled` or `seller_wants_to_drop_out`

---

### 6D — Still Unpaid (Day +5) → Manager Flag

Internal alert to sales manager. Seller marked `at_risk` in ob_tasks.

**WhatsApp (final message):**
> Hi [Name], your store has been fully set up and is waiting for the final step.
>
> We want to make sure you don't miss out — your slot is reserved until [Date].
>
> Please reach out to [Manager Name] directly at [number] if you have any concerns.

---

### 6E — Transfer Confirmed ✅

**WhatsApp:**
> Payment received! ✅ Thank you, [Name].
>
> Your store is now going into final quality review. This takes 24–48 hours.
> We'll message you the moment it's done!

---

## Stage 7: DTR / QC Check

**Trigger:** `qc_check` task opens

### 7A — QC Started

**WhatsApp:**
> Your store is in quality review! 🔍
>
> Our team is checking:
> ✅ Product photos and descriptions
> ✅ Pricing accuracy
> ✅ Ad copy and store experience
> ✅ Payment & delivery settings
>
> Timeline: **24–48 hours.** We'll notify you immediately with results.

---

### 7B — QC Issues Found

**WhatsApp:**
> We've almost cleared your store! Just one fix needed:
>
> ⚠️ **[Specific issue — e.g., "Product photo for [Item] needs a plain background"]**
>
> Can you send an updated [photo/detail]? Once done, we'll approve immediately — no need to wait another 48 hours.

---

### 7C — QC Passed ✅

**WhatsApp:**
> ✅ Quality check passed! Your store looks great, [Name]!
>
> We're activating your ads now. **Your store goes live in the next few hours.**
> Get ready for your first orders 🚀

---

## Stage 8: GTG — Store Goes Live

**Trigger:** `gtg` task disposition = completed

### 8A — Launch Message (Immediate)

**WhatsApp:**
> 🚀 [Name]'s store is LIVE on Shopdeck!
>
> Your ads are running and customers can now find your store.
>
> 📊 Track your orders here: [Dashboard Link]
> 📞 Your account manager: [Name] — [number]
>
> We'll update you the moment your first order comes in. Exciting times ahead!

---

### 8B — Launch Email

**Subject:** You're live — here's what to expect in Week 1

> Hi [Name],
>
> Congratulations — your Shopdeck store is officially live! 🎉
>
> **What happens now:**
> - Your ads start reaching customers immediately
> - Orders will come into your dashboard: [link]
> - You'll get a WhatsApp alert for every new order
>
> **Week 1 targets:**
> - Aim to fulfill orders within [SLA] hours of receiving them
> - Add 5 more products if you can — it helps the algorithm
>
> **Your support contacts:**
> - Account Manager: [Name] — [number]
> - Operations: [number]
> - Helpdesk: [link]
>
> — Team Shopdeck

---

### 8C — First Order Alert (Event-triggered, real-time)

**WhatsApp:**
> 🎉 First order received!
>
> **[Customer Name]** ordered **[Product]** from your store.
>
> 👉 Log in to confirm dispatch: [link]
> ⏱️ Dispatch deadline: [Time] (within [SLA] hours)
>
> Great start — keep it going!

---

### 8D — 7-Day Check-in

**WhatsApp:**
> One week in! Here's your store summary 📊
>
> Orders: [X]
> Revenue: ₹[Y]
> Ads running: [Z]
>
> 💡 Tip for Week 2: Adding [X] more products this week can increase your weekly orders by up to 40%.
>
> Any questions or feedback? Reply here — we're always around.

---

### 8E — 0 Orders After 7 Days → Seller Success Call

**WhatsApp:**
> Hi [Name], your store has been live for 7 days and we want to make sure things are moving.
>
> Our team is reviewing your ads — let's get on a quick call to optimize and get your first orders in. When works for you?

Outbound call by Seller Success team. Review: ad budget, product photos, pricing vs. competition.

---

## No-Response Escalation (All Stages)

| Day | Action | Channel | ob_tasks Update |
|---|---|---|---|
| T+0 | Initial message sent | WhatsApp + Email | — |
| T+1 | Follow-up if no action | WhatsApp | — |
| T+3 | No response → outbound call | Call | `rnr_attempt_1` |
| T+5 | Still no response → manager flagged | Internal alert | `at_risk` |
| T+20 (any stage) | No activity → dormant | — | `dormant` → `churn_seller_callback` task |

---

## Churn Signals to Watch

| Signal | Disposition to Log | Next Action |
|---|---|---|
| Seller says "not interested" | `seller_wants_to_drop_out` | Churn callback within 24h |
| Seller says "pause for now" | `seller_wants_to_pause` | Follow up in 2 weeks |
| No response for 20 days | `dormant` | Reactivation flow |
| Fund transfer refused repeatedly | `not_in_shopdeck_criteria` (if budget issue) | Escalate or close |
| Call never connects (5+ attempts) | `asked_to_drop_the_lead` | Manager review |

---

*Last updated: September 2026 | Branch: claude/customer-journey-plan-jt6fwd*
