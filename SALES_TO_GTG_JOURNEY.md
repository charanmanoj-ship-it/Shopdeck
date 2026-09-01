# Sales → GTG: Full Branch Map

Every decision point, every probable outcome, every response — from sale closed to store live.

---

## How to Read This

Each stage lists every branch point. Indentation = depth into the decision tree.
`→` means "leads to". Outcomes marked `[END: reason]` exit the onboarding flow.

---

## Stage 1: Welcome (T+0 — within 30 min of sale)

**Entry condition:** `ob_ticket` created

---

### Branch 1.1 — Phone Number Available?

**YES → proceed to 1.2**

**NO →**
- Internal alert to sales rep: "Phone missing for [Seller ID] — collect before first contact"
- Hold all messages
  - **Number collected within 4h →** proceed to 1.2 (delayed)
  - **Number not collected in 24h →** escalate to sales manager
    - **Manager provides number →** proceed to 1.2
    - **No number after 48h →** `[END: contact_unreachable]` — ticket flagged for manual closure

---

### Branch 1.2 — What Time Was the Sale?

**Before 1:00 PM, Mon–Fri →**
> "Hi [Name]! 👋 Welcome to Shopdeck — your store setup starts TODAY.
> Your manager [Name] will call you shortly. Keep your phone ready!"
- Schedule first call: within 2–3 hours

**After 1:00 PM, Mon–Fri →**
> "Hi [Name]! 👋 Welcome to Shopdeck!
> Your manager [Name] will call you **tomorrow morning between 10–11 AM**. No action needed from your side today."
- Schedule first call: next morning 10 AM

**Saturday →**
> "Hi [Name]! 👋 Welcome to Shopdeck!
> Your onboarding starts Monday morning — [Manager Name] will call you between 10–11 AM.
> Enjoy your weekend! 🙌"
- Schedule first call: Monday 10 AM

**Sunday →** Same as Saturday message, call scheduled for Monday 10 AM

---

### Branch 1.3 — WhatsApp Delivery Status

**WA delivered →** proceed to Stage 2

**WA undelivered (after 1h) →**
- Send SMS fallback:
  > "Shopdeck: Welcome [Name]! Your store setup has begun. Our manager will call you soon. For queries: [number]"
  - **SMS delivered →** proceed to Stage 2
  - **SMS also fails →** log `contact_unreachable`, notify sales rep immediately

---

### 1.4 — Email (Parallel, Always)

Send regardless of WA/SMS status:

**Subject:** Your Shopdeck store is being set up 🚀

Content: welcome + full docs checklist + expected timeline + manager contact + app link

---

## Stage 2: First Call

**Entry condition:** Call scheduled per Branch 1.2

---

### Branch 2.1 — Call Attempt 1

**ANSWERED →** go to Branch 2.2

**NOT ANSWERED (RNR) →**
- WhatsApp immediately:
  > "Hi [Name], we just tried calling but couldn't connect. Reply here with a good time and we'll call right back! ⏰ Or call us: [number]"
- **Seller replies with time →** call at that time → go to Branch 2.2
- **No reply within 2h →** go to Call Attempt 2

---

### Branch 2.2 — Call Attempt 2 (2–3h after Attempt 1)

**ANSWERED →** go to Branch 2.3

**NOT ANSWERED →**
- WhatsApp:
  > "Hi [Name] 👋 We tried calling again. Your onboarding slot is ready whenever you are!
  > Reply **CALL ME** and we'll reach you within 30 minutes."
- log `rnr_attempt_2`
- **Seller replies CALL ME →** call within 30 min → go to Branch 2.3
- **No reply by next morning →** go to Call Attempt 3

---

### Branch 2.3 — Call Attempt 3 (Next Morning)

**ANSWERED →** go to Branch 2.4 (call outcomes)

**NOT ANSWERED →**
- WhatsApp:
  > "Hi [Name], we've made 3 attempts to reach you. We don't want your store setup to slip.
  > Please call [Manager Name] directly at [number] or reply here. Slot reserved until [Date + 3 days]."
- log `rnr_attempt_3` → create `callback` task → notify sales manager
  - **Manager intervenes + seller responds within 3 days →** call scheduled → Branch 2.4
  - **No response for 5 days total →** `[END: unresponsive_post_sale]` — lead marked cold

---

### Branch 2.4 — Call Answered: Seller Response

**Seller is engaged and ready →** proceed normally to Stage 3
- Post-call WA:
  > "Great call [Name]! ✅ Summary: [discussion points]. Next step: [action]. Follow-up: [date/time]. Questions? Reply here or call [number]."
- Post-call Email: summary + next steps + follow-up date

**Seller has questions / needs time to think →**
- Address questions on call
- Send follow-up WA with answers written out
- Schedule follow-up call (within 24h)
  - **Follow-up call: still engaged →** proceed to Stage 3
  - **Follow-up call: declines →** go to Seller Says Not Interested below

**Seller says "not interested anymore" →**
- Agent attempts objection handling on call
  - **Convinced →** proceed to Stage 3
  - **Not convinced →** log `seller_wants_to_drop_out`
    - Sales manager callback within 24h (retention attempt)
      - **Re-engaged →** proceed to Stage 3 (restarted)
      - **Final refusal →** `[END: seller_dropped_post_sale]`

**Seller says "call me back later today" →**
- Schedule callback at seller's requested time
- go to Branch 2.4

**Seller says "I'm busy this week" →**
- Offer earliest available next-week slot
- Send calendar invite / WA confirmation
- **Shows up →** go to Branch 2.4
- **No-show again →** treat as Call Attempt 3 outcome (manager flag)

**Wrong person picks up (not the seller) →**
- Ask for best time to reach [Seller Name]
- Call back at given time → go to Branch 2.4
- **Can't reach seller through this number →** flag to sales rep for correct number

---

## Stage 3: Docs Collection

**Entry condition:** CAGD task completed, KYC task opens

---

### Branch 3.1 — Initial Doc Request (WA)

> "Great session! ✅ Now to move forward, we need 3 documents:
> 1️⃣ Aadhaar (front + back)  2️⃣ PAN Card  3️⃣ Bank passbook / cancelled cheque
> Just send the photos in this chat — usually takes 10 min!"

---

### Branch 3.2 — What Docs Were Received? (within 48h)

**All 3 docs received, clear quality →** go to Branch 3.5 (docs verified)

**Partial docs received:**
- Aadhaar missing → WA: "We still need your Aadhaar (front + back) — can you send it now?"
  - Sends Aadhaar → go to Branch 3.5
  - Doesn't send within 24h → outbound call (Aadhaar is mandatory, cannot proceed)
- PAN missing → WA: "PAN Card is optional for now — we can proceed and collect it before launch. Want to share it now or later?"
  - Shares now → proceed with all docs
  - Shares later → note in ob_tasks, proceed without PAN for now
- Bank doc missing → WA: "Can you share your bank passbook or a cancelled cheque? We need it to set up your payouts."
  - Shares → proceed
  - Doesn't share within 24h → call to unblock

**No docs received after 48h →** go to Branch 3.3

---

### Branch 3.3 — 48h No Docs: Follow-up

**WA:**
> "Hi [Name], we're still waiting on your documents to move your store setup forward.
> Once received, your store goes into the next step within 24 hours 📦
> Stuck on something? Reply YES and we'll help right away."

**SMS (parallel):**
> "Shopdeck: KYC docs pending. Share Aadhaar, PAN & bank doc on WA: [number]. Store launch on hold. Call: [number]"

- **Docs received →** go to Branch 3.2 (re-check)
- **No response after 24h more →** go to Branch 3.4 (call)

---

### Branch 3.4 — Day +3: Outbound Call to Unblock

Agent calls. Common blockers + resolutions:

| Blocker | Agent Action | ob_tasks Note |
|---|---|---|
| "Don't have PAN" | Proceed without PAN, collect before GTG | `pan_pending` |
| "Don't have GST" | Not required — proceed | `gst_not_applicable` |
| "Bank doc format unclear" | Accept passbook screenshot / statement | — |
| "Aadhaar address is old" | Accept, note discrepancy | `address_mismatch` |
| "Docs are in someone else's name" | Flag to compliance team | escalate |
| "I'll send tomorrow" | Set reminder, follow up next morning | `callback_scheduled` |
| Doesn't answer call | WA: "Tried calling — please share docs when you can. We're here if you need help." | `rnr_docs_stage` |

- **Blocker resolved on call →** docs received → Branch 3.5
- **Call unanswered + 3 days no docs from KYC task open →** flag to manager
  - **Manager re-engages seller →** docs flow resumes
  - **Seller unresponsive 5+ days →** `[END: docs_collection_failed]` — churn initiated

---

### Branch 3.5 — Docs Received: Quality Check

**All docs clear and readable →**
- WA: "Documents received! ✅ Our team is verifying them — up to 24 hours. Next: we'll help you upload your products!"
- Proceed to Stage 4

**Doc quality issues:**
- Blurry / too dark → WA: "Could you re-send [doc] — the image is a bit unclear. A well-lit photo works perfectly!"
  - Re-sent and clear → proceed
  - Multiple bad attempts → offer to schedule video call to capture doc live
- Wrong document (e.g., voter ID instead of Aadhaar) → WA: "We need the Aadhaar card specifically — could you share that instead?"
- Name mismatch between docs → flag to compliance manually, hold until resolved
  - **Compliance clears →** proceed
  - **Compliance flags issue →** `[END: kyc_compliance_hold]` — seller informed, re-apply required

---

## Stage 4: Catalogue Upload

**Entry condition:** `catalogue_config` task opens

---

### Branch 4.1 — Upload Preference

**WA:**
> "Time to add your products! 🛍️ Two options:
> **A)** Send us photos + prices in this chat — we upload for you.
> **B)** Use our Excel template: [link]
> Most sellers go with A). Drop your first product photo here to get started!"

**Seller chooses Option A (concierge) →** go to Branch 4.2
**Seller chooses Option B (self-upload) →** go to Branch 4.3
**No response after 24h →** go to Branch 4.4

---

### Branch 4.2 — Concierge Upload (Team Uploads)

**Seller sends photos + prices →**
- ≥15 products worth of content:
  - Team uploads within 24h
  - WA: "Your catalogue is live — [X] products added! 🎉 Next step: Meta setup."
  - Proceed to Stage 5

- <15 products sent:
  - WA: "Got [X] products — we need at least 15 to launch well. Can you send [15-X] more?"
    - **Sends more →** Team uploads → proceed
    - **Says "I only have [X] products" →** Check if ≥10
      - ≥10: Launch with what's available, note in ob_tasks `limited_catalogue`
      - <10: Advise adding more or sourcing more products before going live — delay Stage 5 until minimum met

- Photos received but poor quality (blurry, irrelevant):
  - WA: "A few of these photos might not display well in your store. Could you re-shoot [specific items] with better lighting / plain background?"
    - **Re-sends →** upload and proceed
    - **Can't re-shoot →** team edits basic contrast/brightness if possible, proceed with note

---

### Branch 4.3 — Self-Upload (Excel / Dashboard)

**Email:** Template + photo guidelines + pricing benchmark sent Day +1

**After 3 days — check product count:**
- ≥15 products uploaded → proceed to Stage 5
- 5–14 products:
  - WA: "You've added [X] products — great start! Aim for 15 to launch strong. Need help with the remaining [15-X]? Reply YES and we'll add them for you."
    - Uploads more → proceed
    - Accepts concierge help → go to Branch 4.2 for remaining
- <5 products or none:
  - WA: "Looks like the catalogue is still quite empty. Want us to handle the upload for you? Just send photos + prices in this chat 📷"
    - Agrees → go to Branch 4.2
    - Disagrees but keeps trying → re-check in 2 days
    - No progress for 5 days total → outbound call

**Outbound call (Day +5, catalogue stuck):**
- Seller has products but unsure how to use template → walk through on call, or switch to concierge
- Seller has no products ready:
  - Products arriving soon (within 1 week) → pause catalogue step, schedule check-in
  - Products more than 2 weeks away → advise delay, reschedule entire onboarding or hold slot
  - No products at all (miss-sold) → `[END: seller_no_inventory]` — escalate to sales team

---

### Branch 4.4 — No Response to Catalogue Message (24h)

WA follow-up:
> "Hey [Name] 👋 Ready to get your products on Shopdeck? You can start as easily as sending me 1 product photo right now to see how it works!"

- Responds → go to Branch 4.1
- 48h more silence → call → Branch 4.3 outbound resolution

---

### Branch 4.5 — Catalogue Complete ✅

**WA:**
> "Your catalogue is ready — [X] products on your store! 🎉
> Next: connecting your Facebook account so ads can run and bring you customers.
> [Manager Name] will walk you through it. Should take ~20 min!"

Proceed to Stage 5.

---

## Stage 5: Meta / WD / Domain Setup

**Entry condition:** `meta_setup` task opens

---

### Branch 5.1 — Does Seller Have a Facebook Account?

**WA:**
> "Almost there! One important step — connecting your Facebook Business account.
> Do you have a Facebook account? Reply YES / NO"

**YES, has Facebook →** go to Branch 5.2
**NO Facebook account →** go to Branch 5.3
**No reply after 24h →** send step-by-step guide (Branch 5.4), call on Day +2

---

### Branch 5.2 — Has Facebook: Does Seller Have a Business Page?

**YES, has Business Page →** go to Branch 5.5 (attempt connection)

**NO Business Page →**
- WA: "No problem! We'll create your Facebook Business Page first — takes 5 min. Want to do it on a quick call? Reply YES."
  - **Yes →** schedule screen-share call → create page together → Branch 5.5
  - **No, will do it alone →** send step-by-step Business Page creation guide
    - Created → Branch 5.5
    - Stuck / not done in 48h → outbound call → create page together → Branch 5.5

---

### Branch 5.3 — No Facebook Account at All

**WA:**
> "No worries! You'll need a personal Facebook account first. Here's how:
> 1. Go to facebook.com → Sign Up → Use your personal name & number
> 2. Verify the number
> 3. Reply here when done — we'll connect it to Shopdeck!
> Takes about 5 minutes. Let us know if you need help."

- Creates account → go to Branch 5.2
- Refuses to create Facebook account:
  - Explain Meta's role in driving orders (mandatory for current ad model)
  - Manager call to address concern
    - **Agrees and creates →** Branch 5.2
    - **Firm refusal →** `[END: meta_setup_refused]` — flag to product team, seller informed store can't launch without Meta connection under current model

---

### Branch 5.4 — Connection Attempt

WA step-by-step guide:
> 1️⃣ Go to [link]  2️⃣ Click "Connect Facebook"  3️⃣ Log in  4️⃣ Select Business Page  5️⃣ Approve permissions
> Stuck at any step? Reply with the step number!

**Connected successfully →** go to Branch 5.6
**Error at Step 2 (Shopdeck login issue) →** tech support ticket, resolve within 24h
**Error at Step 3 (Facebook login issue) →**
- Wrong password → help reset Facebook password
- 2FA issue → guide through 2FA
**Error at Step 4 (Page not showing) →** Business Page visibility settings — guide fix
**Error at Step 5 (Permissions denied) →** re-attempt with correct FB admin access
**General "it's not working" →** schedule screen-share call

---

### Branch 5.5 — Screen-Share Call for Meta Setup

**Call happens, setup completed →** Branch 5.6

**Call happens, but Meta account is restricted/banned:**
- WA: "Your Facebook account has a restriction that's blocking the connection. Our tech team will look into it."
- Tech team reviews within 24–48h
  - **Resolvable →** fix → Branch 5.6
  - **Account permanently banned →** seller needs new FB account → restart Branch 5.3
  - **Unresolvable within 5 days →** `[END: meta_account_blocked]` — escalate to product team

**Seller no-shows scheduled call (attempt 1) →**
- WA: "Missed our screen-share! Let's reschedule — what time works?"
  - **New time confirmed →** reschedule → call
  - **2nd no-show →** final attempt with strong urgency message → if still absent → manager flag

---

### Branch 5.6 — Meta Setup Complete ✅

**WA:**
> "Facebook connected! ✅ Your ads are almost ready to run.
> Last step: the initial fund transfer to activate your ad budget.
> [Manager Name] will call you with all the details."

Proceed to Stage 6.

---

## Stage 6: Fund Transfer

**Entry condition:** `fund_transfer` task opens

---

### Branch 6.1 — Initial Payment Request

**WA:**
> "Hi [Name]! One last step before going live 🏁
> Transfer ₹[Amount] to activate your store's ad campaigns.
>
> 📌 This is your ad budget — not a fee. Every rupee drives customers to your store.
>
> 🏦 Account: [Name] | [Acc No] | IFSC: [Code] | Ref: [Seller ID]
>
> Once done, share the UTR or screenshot here → confirmed in 2h. ✅"

---

### Branch 6.2 — Payment Response (within 24h)

**Full amount paid, UTR shared →** go to Branch 6.7 (confirmed)

**Full amount paid, UTR NOT shared →**
- WA: "Thanks! Just share the UTR number or screenshot and we'll confirm right away."
  - **Shares UTR →** Branch 6.7
  - **Doesn't share after 12h →** finance verifies via bank records → confirm if found → Branch 6.7

**Partial payment made →**
- Finance team reviews
  - **Partial accepted (case-by-case) →** note shortfall, proceed with condition: top-up before GTG
  - **Partial not accepted →** WA: "We received ₹[X] — to activate your ads, we need the full ₹[Amount]. Can you transfer the remaining ₹[Amount - X] today?"
    - Tops up → Branch 6.7
    - Can't top up → go to Branch 6.3 (objections)

**Excess payment →**
- Finance notes excess
- WA: "We received ₹[X] — we'll credit the extra ₹[excess] to your account. Your store is now active!"
- Branch 6.7

**No payment, no response after 24h →** go to Branch 6.3

---

### Branch 6.3 — Objection Handling (Day +2 Call)

Agent calls to address hesitation:

**"Why pay before I get orders?" →**
> "This is your ad spend — it goes directly into running Facebook and Google campaigns for your store. Think of it as stocking your ad shelf. You earn it back through orders — most sellers recover it within 10–15 days."
- **Convinced →** proceeds to pay → Branch 6.7
- **Not convinced →** ask "What would make you comfortable?" → document concern → escalate to manager

**"I need more time / cash flow issue right now" →**
- Offer 3-day extension: "Totally understand. Can you arrange it by [date, 3 days out]?"
  - **Pays within extension →** Branch 6.7
  - **Misses extension →** final manager call (1 attempt)
    - **Pays →** Branch 6.7
    - **Still can't →** `[END: fund_transfer_failed_cashflow]` — note in ob_tasks, slot released

**"Is there an EMI option?" →**
- Check with finance (case by case)
  - **EMI available →** set up, confirm first installment, proceed
  - **Not available →** explain one-time payment requirement → objection handling continues

**"I want to cancel / not interested" →**
- log `seller_wants_to_drop_out`
- Manager retention call within 24h
  - **Re-engaged →** return to Branch 6.1
  - **Confirmed cancellation →** `[END: seller_cancelled_at_payment]`

**"How do I know this is safe / legitimate?" →**
- Share Shopdeck credentials, company registration, existing seller references if available
- Offer video call with senior manager
  - **Convinced →** pays → Branch 6.7
  - **Still unconvinced →** `[END: trust_issue_unresolved]` — document and escalate to leadership

**Wrong bank details entered by seller →**
- Seller raises issue
- Finance confirms no receipt within 48h → ask seller to check transaction
  - **Sent to wrong account →** seller initiates reversal with their bank → re-transfer once reversed
  - **Still in transit →** wait 72h → confirm

---

### Branch 6.4 — Day +5: No Payment, All Objections Tried

**Internal alert to sales manager**
- Manager makes final call
  - **Seller pays →** Branch 6.7
  - **Confirmed drop →** `[END: seller_dropped_at_fund_transfer]`
  - **Asking for extended hold →** hold slot max 7 more days with manager approval → if still unpaid after that → `[END: slot_expired]`

---

### Branch 6.7 — Payment Confirmed ✅

**WA:**
> "Payment confirmed! ✅ Thank you, [Name].
> Your store is now going into final quality review. This takes 24–48 hours.
> We'll message you the moment it's done — almost there!"

Proceed to Stage 7.

---

## Stage 7: DTR / QC Check

**Entry condition:** `qc_check` task opens

---

### Branch 7.1 — QC Initiated

**WA:**
> "Your store is in quality review! 🔍
> We're checking: product photos, pricing, ad copy, delivery settings.
> Timeline: **24–48 hours.** You'll hear from us the moment it's done!"

---

### Branch 7.2 — QC Outcome

**All checks pass on first review →** go to Branch 7.6 (QC passed)

**Minor issues found (fixable by seller):**
Examples: low-quality product photo, missing product description, price looks incorrect
- WA: "Almost there! Just one fix: [specific issue]. Can you send [updated photo / corrected info]? Once done, we approve immediately — no need to wait another 48h."
  - **Fix received, acceptable →** Branch 7.6
  - **Fix received, still not acceptable →** second specific feedback → one more attempt
    - **Still not acceptable →** QC team edits internally if minor → proceed
    - **Cannot fix without seller (e.g., product category issue) →** go to Branch 7.3

**Major issues found (policy / compliance):**
- Prohibited product category → go to Branch 7.3
- Pricing anomaly (too high/too low vs. market) → advise repricing
  - **Repriced →** re-QC → Branch 7.6
  - **Refuses to change price →** note in ob_tasks, proceed with advisory flag
- False product claims in description → request edit
  - **Edited →** proceed
  - **Refuses →** QC hold until resolved → if 72h stuck → escalate to senior QC lead

**QC team unavailable / delayed (>48h) →**
- WA to seller: "Your store review is taking a little longer than expected — we'll have an update within [X] hours. Thanks for your patience!"
- Internal escalation to QC lead to prioritise

---

### Branch 7.3 — Prohibited Product / Compliance Issue

- WA: "We noticed your catalogue includes [product type] which isn't available on Shopdeck at the moment."
- Options:
  - **Seller removes/replaces those products →** re-QC → Branch 7.6
  - **All products are in the prohibited category →** `[END: catalogue_compliance_failure]` — full refund discussion, escalate to sales
  - **Partial prohibited →** remove those, launch with remaining (if ≥10 products still)

---

### Branch 7.4 — Multiple QC Rounds (>2 rounds of feedback)

- Escalate to senior QC lead for direct review
- Senior QC calls seller directly to align on standards
  - **Resolved →** Branch 7.6
  - **Irreconcilable (seller unwilling to fix) →** `[END: qc_failed_seller_non_compliance]`

---

### Branch 7.6 — QC Passed ✅

**WA:**
> "✅ Quality check passed! Your store looks great, [Name]!
> We're activating your ads now — **your store goes live in the next few hours.**
> Get ready for your first orders 🚀"

Proceed to Stage 8.

---

## Stage 8: GTG — Store Live

**Entry condition:** `gtg` task disposition = completed

---

### Branch 8.1 — Launch Messages (Immediate)

**WA:**
> "🚀 [Name]'s store is LIVE on Shopdeck!
> Ads are running. Customers can find your store right now.
> 📊 Track orders here: [dashboard link]
> 📞 Your manager: [Name] — [number]
> We'll ping you the moment your first order comes in!"

**Email:** Launch summary — week 1 guide, support contacts, tips, dashboard link

---

### Branch 8.2 — First Order

**Within 24h of going live →**
- WA (real-time alert):
  > "🎉 First order! [Customer] ordered [Product]. Dispatch by [time]. Log in: [link]"
- WA (follow-up if not dispatched within SLA/2):
  > "Reminder: [Order] needs to be dispatched in [X] hours to maintain your rating!"
  - **Dispatched on time →** great, note in ob_tasks `first_order_dispatched`
  - **Dispatched late →** note, advise on SLA importance
  - **Not dispatched (seller MIA) →** outbound call immediately
    - **Seller resolves →** dispatch completed
    - **Seller unreachable →** operations team handles, flag to seller success

**Day 1–7: orders coming in regularly →** 7-day check-in (Branch 8.4)

---

### Branch 8.3 — No Orders in 3 Days

**WA:**
> "Hi [Name] 👋 Your store has been live for 3 days. Your ads are running — orders usually start picking up in the first week.
> Tip: Make sure your store link is shared with anyone who might want to order!"

---

### Branch 8.4 — 7-Day Check-in

**WA:**
> "One week in! Here's your store summary 📊
> Orders: [X] | Revenue: ₹[Y] | Ads running: ✅
>
> 💡 Week 2 tip: Adding [5] more products typically increases weekly orders by ~40%.
> Any questions or feedback? Reply here."

---

### Branch 8.5 — 0 Orders After 7 Days

**WA:**
> "Hi [Name], your store has been live for 7 days. We want to make sure everything is set up for success.
> Can we get on a quick call to review your store together? Reply YES."

**Seller Success outbound call — check:**
- Ad budget sufficient?
- Product pricing competitive vs. market?
- Product photos quality
- Catalogue breadth (too few products?)
- Meta connection still active?
- Delivery pincode coverage

  - **Issues found → fixes made →** re-check in 3 days
    - Orders start coming → retain → ongoing
    - Still 0 orders after fixes → escalate to senior seller success + ops review
  - **No issues found, just slow start →** reassure, check again in 7 days
    - **Orders within 14 days of GTG →** normal, continue
    - **Still 0 at Day 14 →** `[END: launch_no_traction]` — deep review, potential ad strategy reset

---

### Branch 8.6 — Post-GTG Seller Goes Dormant

Seller stops responding after going live (not dispatching orders, no WhatsApp response):
- Day 3 no dispatch: WA + call
- Day 7 unresponsive: seller success manager call
- Day 20 no activity since GTG: mark `dormant`, create `churn_seller_callback` task
  - **Re-engages →** reactivation support
  - **Formally churns →** `[END: post_gtg_churn]`

---

### Branch 8.7 — Seller Wants to Pause After GTG

- Log `seller_wants_to_pause` in ob_tasks
- WA: "Understood! We'll pause your campaigns. When would you like to resume? We'll keep your store ready."
- Schedule check-in for requested resume date
  - **Resumes →** reactivate campaigns, continue
  - **No response on resume date →** WA + call
    - **Resumes late →** reactivate
    - **Permanent pause →** treat as churn

---

## Churn Exit Points: Summary

| Exit Code | Stage | Cause |
|---|---|---|
| `contact_unreachable` | Welcome | No phone number, unresolvable |
| `unresponsive_post_sale` | First Call | 5+ days no response after sale |
| `seller_dropped_post_sale` | First Call | Seller explicitly cancelled after call |
| `docs_collection_failed` | Docs | 5+ days no docs, all attempts exhausted |
| `kyc_compliance_hold` | Docs | Doc verification failed compliance |
| `seller_no_inventory` | Catalogue | No products to sell |
| `meta_setup_refused` | Meta | Refused to create Facebook account |
| `meta_account_blocked` | Meta | FB account banned, unresolvable |
| `fund_transfer_failed_cashflow` | Payment | Extended cash flow issue |
| `seller_cancelled_at_payment` | Payment | Explicitly cancelled at payment stage |
| `trust_issue_unresolved` | Payment | Could not establish trust |
| `slot_expired` | Payment | Held too long without payment |
| `seller_dropped_at_fund_transfer` | Payment | Confirmed drop after all objections |
| `catalogue_compliance_failure` | QC | All products in prohibited category |
| `qc_failed_seller_non_compliance` | QC | Refused to meet QC standards |
| `launch_no_traction` | GTG | 0 orders 14 days post-launch after fixes |
| `post_gtg_churn` | GTG | Went dormant after going live |

---

## No-Response Escalation (All Stages)

| Day from stage open | Action | Channel | ob_tasks |
|---|---|---|---|
| Day 0 | Initial message | WA | — |
| Day 1 | Follow-up | WA | — |
| Day 2 | Second follow-up | WA + SMS | — |
| Day 3 | Outbound call attempt 1 | Call | `rnr_attempt_1` |
| Day 4 | Outbound call attempt 2 | Call | `rnr_attempt_2` |
| Day 5 | Manager flag + final WA | Call + WA | `at_risk` |
| Day 7 | Manager outreach | Call | `manager_contacted` |
| Day 20 (any stage) | Dormant | — | `dormant` → `churn_seller_callback` |

---

*Last updated: September 2026 | Branch: claude/customer-journey-plan-jt6fwd*
