---
name: shopdeck-code-snippet
description: Build custom HTML/CSS/JS for a Shopdeck homepage section and hand it to a POC as one paste-ready blob. Use when someone asks for a Shopdeck storefront section, homepage widget, code_snippet_widget, custom section for a seller's store, an editorial statement band, marquee/announcement ticker, fabric or product story split, promise/trust strip, or lookbook grid — or asks where a POC pastes a snippet in pro.shopdeck.com. Also use for reviewing or fixing an existing Shopdeck snippet. Never edits, saves, or publishes live widgets; the POC pastes and publishes.
---

# Hand a Shopdeck code snippet to the POC

Produce the custom HTML/CSS/JS for one Shopdeck homepage section, plus copy-paste
instructions for the POC.

**You never edit, save, or Publish live widgets. The POC pastes.**

## Inputs

| Input | Meaning | If missing |
|---|---|---|
| `{section_goal}` | What the seller/POC wants (editorial statement, marquee, fabric story…) | Ask — this one is required |
| `{brand_tokens}` | Colors, fonts, copy, images, or "match existing store" | Use clear placeholders, never invented brand facts |
| `{widget_name}` | Display name for the widget row | Invent a short ALL-CAPS title |
| `{seller_id}` | Seller to hand off to | Leave `{seller_id}` in the paste path |

## Output — always all four

1. **One paste-ready blob** in a single fenced block: section markup, then `<style>`, then `<script>`.
2. **A preview note** — 2–3 lines on how it should look on mobile and desktop. Render a
   local preview file first if the layout is non-obvious.
3. **The POC paste path** (numbered, below).
4. **Widget naming** — what to call the row, and whether to Edit an existing
   `code_snippet_widget` row or use **+ Add Widget**.

## Snippet rules (`code_snippet_widget`)

- One self-contained paste. Order is fixed: markup → `<style>` → `<script>`.
- Brand-prefix every CSS class (`btc-…`, `sd-…`) so theme CSS cannot collide.
  Prefix custom properties too (`--btc-ink`).
- **No external CDN scripts or stylesheets.** No Google Fonts link — use font
  stacks that inherit the theme (`inherit`, or a Georgia/Times serif stack).
  Inline SVG data URIs for texture are fine.
- Full-bleed breakout when the section should run edge-to-edge:
  `width:100vw; margin-left:calc(50% - 50vw); margin-right:calc(50% - 50vw);`
- Mobile and desktop layout in the same blob. Mobile-first, one `min-width` breakpoint.
- Respect `prefers-reduced-motion: reduce` — motion off, content still readable.
- JS is an IIFE, queries only its own root class, and guards: `if (!root) return;`
- Never leave content parked at `opacity: 0` waiting on an observer. Default CSS is
  visible; the script arms the pre-reveal state only for elements currently below the
  fold, then reveals via `.is-active` + IntersectionObserver. No JS, no flash, no
  blank band.
- Idempotent: the POC may paste twice. Guard with a `data-` flag on the root.
- Unknown seller copy, colors and image URLs stay as obvious placeholders
  (`REPLACE-hero.jpg`), never plausible-looking inventions.

Gold-standard shape: the Bombay Textile **"WEAR THE SLOWER SIDE."** samples —
editorial typography, hairline rules, staggered scroll reveal.

## POC paste path

Signed-in Chrome at `https://pro.shopdeck.com`.

1. **Sellers → Sellers List**
2. Set the search filter to **Seller Id**, enter `{seller_id}`, find the row
3. Click **Log in as Seller** (a banner confirms logged-in-as)
4. **Website → Website Pages** → open the **Home** list (`/website/website-pages/home`)
5. Find a row of type **`code_snippet_widget`**, or **+ Add Widget** → choose that type
6. **Edit >** on the row → paste the whole blob into the code field → save in the editor
7. The POC uses **Preview**, then **Publish** when ready (propagation up to ~2 hours)

Map live storefront sections to widget rows by title — live "WEAR THE SLOWER SIDE."
is the same-named `code_snippet_widget` row.

## Anti-jobs

- Do not **Log in as Seller** to mutate production unless the user explicitly asks and confirms.
- Do not click **Publish**. Ever.
- Do not paste credentials, OTPs, or phone numbers into skills, chat, or commits.
- Do not invent widget types other than `code_snippet_widget` for freeform HTML/CSS/JS.
- Do not claim the snippet was tested against the seller's live theme. Prefixing
  reduces collisions; it does not prove there are none. Say so.

## Report back

Widget name → blob in one fenced block → preview note → the numbered paste path.
Nothing else in the handoff message.

## Self-service builder

The five repeat section types (editorial statement, marquee, story split, promise
strip, lookbook grid) are also available as a shareable page a POC can drive without
an agent: fill brand tokens, copy the blob, copy the handoff note.

Builder: https://claude.ai/code/artifact/66309a59-1694-4380-aa80-1b5b179e384e
