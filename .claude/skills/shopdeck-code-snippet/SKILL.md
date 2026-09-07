---
name: shopdeck-code-snippet
description: Write the custom HTML/CSS/JS for a Shopdeck storefront homepage section and hand it to a POC as one paste-ready blob, audited against the code_snippet_widget rules. Use this whenever someone wants a Shopdeck homepage section, storefront widget, code_snippet_widget, or custom band for a seller's store — an editorial statement, marquee or announcement ticker, fabric/craft/founder story split, promise or trust strip, lookbook or product grid — and also when they ask where a POC pastes a snippet in pro.shopdeck.com, ask you to review or fix an existing Shopdeck snippet, or say a seller's section is broken, colliding with the theme, or blank on mobile. Reach for it even when the request is phrased as plain frontend work ("write me a hero band for this store"), because Shopdeck's single-code-field constraint changes what correct code looks like. Never edits, saves, or publishes live widgets — the POC pastes and publishes.
---

# Shopdeck code snippets

Shopdeck's `code_snippet_widget` gives a seller's homepage **one code field**. Everything
for a section — markup, styles, behaviour — goes in as a single continuous paste, into a
page whose theme CSS you cannot see and did not write.

That constraint is the whole job. It is why a snippet that would be unremarkable in a
normal codebase is wrong here: no build step, no separate stylesheet, no way to load a
font file, no second field for mobile, and a class name like `.container` will collide
with the theme and quietly break a live storefront.

**You write the code. The POC pastes and publishes. You never do.**

## What to produce

Four things, every time. The POC needs all four to act without coming back to you.

1. **The blob** — one fenced block: markup, then `<style>`, then `<script>`. Nothing else in it.
2. **A preview note** — two or three sentences on how it looks on mobile and on desktop.
   Write what a person would see, not what the CSS says.
3. **The paste path** — the numbered steps below, with the seller id filled in.
4. **The widget name**, and whether to Edit an existing `code_snippet_widget` row or use
   **+ Add Widget**.

## How to work through it

**Read the brief for what the section has to accomplish**, not just what it should contain.
"A band about our fabric" and "convince people handloom is worth 3x powerloom" produce
different sections. Ask only when a wrong guess would waste the POC's time — a missing
image URL becomes a placeholder, a missing intent does not.

**Pick the shape.** `references/templates.md` has five audited starting points — editorial
statement, story split, promise strip, lookbook grid, marquee — each with the brief it
suits and the code to start from. Read that file when the request resembles any of them.
When it resembles none, write fresh against the contract below; do not bend a template
into a shape it was not built for.

**Keep unknowns visibly unknown.** `REPLACE-hero.jpg`, `[SELLER NAME]`, `[PRICE]`. A
plausible invented delivery promise or certification is worse than an obvious blank,
because a POC will paste it and a seller will publish it.

**Audit before you hand it over:**

```bash
python3 scripts/audit_snippet.py /path/to/snippet.html
```

Eight text checks, exit 0 when they all pass. It catches what is cheap to get wrong and
expensive to find after a homepage is live. It cannot tell you the section looks right —
`references/audit.md` explains what each check is defending against and what the script
still cannot see.

## The contract

Every snippet obeys these because of what the paste field is, not because of house style.

**One paste, fixed order** — markup, then `<style>`, then `<script>`. The field renders
top to bottom, so styles must land before the script runs.

**Prefix every class and custom property** (`btc-`, `sd-`). Every value of every class
attribute, and `--btc-ink` rather than `--ink`. This is the only thing standing between
your section and the theme's own selectors.

**Nothing external.** No `<script src>`, no `<link rel=stylesheet>`, no `@import`, no
Google Fonts, no CDN. Fonts come from stacks already on the device — an editorial serif
is `Georgia, "Times New Roman", Times, serif`; to match the theme, use `inherit`. Inline
SVG data URIs for texture are fine.

**Full-bleed the root** when the section should run edge to edge, or it will sit inside
the theme's max-width container:

```css
width: 100vw;
margin-left: calc(50% - 50vw);
margin-right: calc(50% - 50vw);
```

**One blob serves both widths.** Mobile-first, then a `min-width` breakpoint — or fluid
`clamp()` sizing that needs no breakpoint at all. There is no second field for mobile.

**Respect `prefers-reduced-motion: reduce`** by switching off transitions and animations
and leaving the content readable. A marquee becomes a static wrapped row, not a hidden one.

**Never park content at `opacity: 0`.** This is the rule most worth understanding, because
the obvious way to build a scroll reveal is the broken way. If the CSS hides text until
JavaScript reveals it, then any JS failure — an error thrown by another widget on the
page, a browser that never fires the observer — leaves a permanent blank band on a live
storefront. So: the CSS default state is visible, and the script arms the pre-reveal state
only for elements currently below the fold, then reveals them with an IntersectionObserver.
Nothing above the fold is ever hidden, so nothing flashes, and a dead script degrades to
a section that simply does not animate. The templates implement this; copy the pattern
rather than reinventing it.

**Guard the script.** One IIFE. Look up your own root, `if (!root) return;`, and set a
prefixed `data-` flag on it so a second paste of the same blob cannot bind twice — POCs
do paste twice. Query nothing outside your own root: other widgets share the page.

**Semantic markup.** One `<section>` root, a real heading, `alt` on every image,
`loading="lazy"`, and an `aria-label` when the section has no visible heading.

**Nothing clever.** No inline event handlers, no `document.write`, no `eval`, no `fetch`,
no `localStorage`, no cookies. A homepage band has no business doing any of it.

## POC paste path

Signed-in Chrome at `https://pro.shopdeck.com`. Steps 1–3 set the seller context that
step 4 depends on, so the order is not optional.

1. **Sellers → Sellers List**
2. Set the search filter to **Seller Id** (the filter dropdown, not the free-text box),
   enter `{seller_id}`, find the row
3. **Log in as Seller** — a banner confirms who you are acting as
4. **Website → Website Pages → Home** (`/website/website-pages/home`)
5. Find a row of type **`code_snippet_widget`**, or **+ Add Widget** → choose that type
6. **Edit >** on the row → paste the whole blob into the code field → save in the editor
7. **Preview**, then **Publish** when ready — propagation can take up to ~2 hours

Live storefront sections map to widget rows by title: the live "WEAR THE SLOWER SIDE."
band is the same-named `code_snippet_widget` row.

## What you do not do

- **Do not click Publish.** It is the POC's call on the seller's live storefront.
- **Do not Log in as Seller to change production** unless the user explicitly asks and
  confirms. Reading to diagnose is different from mutating; say which you are doing.
- **Do not claim the snippet was tested against the seller's live theme.** Prefixing
  reduces collisions; it does not prove there are none. Say so in the handoff — the
  POC's Preview step is the real check.
- **Do not paste credentials, OTPs, or phone numbers** into skills, chat, or commits.
- **Do not invent widget types.** For freeform HTML/CSS/JS it is `code_snippet_widget`.

## The self-service tool

`assets/code-snippet-tool.html` is the same job as a page a non-technical POC can drive:
a brief plus brand tokens in, a generated section out, with the live preview, the audit
and the paste path built in. It calls Claude through the Artifact `sample` capability, on
**the viewer's own** Claude account, and falls back to the five templates when that is
unavailable.

To give someone their own copy, publish it as an Artifact from their account with
`capabilities: {sample: {}}` and a favicon. Each person publishing their own copy also
sidesteps cross-workspace artifact sharing, which some organizations disable.

Keep this SKILL.md canonical. When the contract above changes, the bundled page does not
change with it — republish it deliberately.

## Reference files

- `references/templates.md` — the five section shapes, when each fits, and full audited code
- `references/audit.md` — what each of the eight checks defends against, and its blind spots
- `scripts/audit_snippet.py` — run the eight checks on a file
- `assets/code-snippet-tool.html` — the POC-facing builder page
