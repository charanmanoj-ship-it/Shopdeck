# The eight checks

`scripts/audit_snippet.py <file>` runs these and exits 0 when they all pass.

They are text checks. Each one exists because it catches a specific way a snippet fails
*after* it reaches a live storefront, where the cost of discovery is a seller's homepage
looking broken. None of them tell you the section looks right.

```bash
python3 scripts/audit_snippet.py snippet.html            # prefix inferred from the first class
python3 scripts/audit_snippet.py snippet.html --prefix btc-
```

The prefix is inferred from the first class attribute when you do not pass one, because
the rule is that every class shares *one* prefix — whichever it is.

## What each check defends against

**`order-markup-style-script`** — The paste field renders top to bottom. A script that
runs before its styles exist can measure the wrong geometry, and an IntersectionObserver
armed against unstyled elements arms against the wrong rects.

**`classes-prefixed`** — The one check with no workaround. You cannot see the seller's
theme CSS, and themes define `.container`, `.title`, `.grid`, `.btn`. An unprefixed class
is an invitation for the theme to restyle your section, or for your section to restyle the
theme. The failure prints the offending class names.

**`no-external-assets`** — There is no build step and no guarantee an external host is
reachable from a seller's storefront. A Google Fonts link fails silently and the section
renders in a fallback nobody chose. Fonts come from device stacks.

**`full-bleed-breakout`** — Without `width:100vw` and the negative margins, the band sits
inside the theme's max-width container. It will not look wrong so much as look like it was
not meant to be there.

**`adapts-across-widths`** — One paste serves mobile and desktop; there is no second field.
Satisfied by a `min-width` breakpoint *or* by fluid `clamp()` sizing that needs no
breakpoint. Both are legitimate — a fully fluid section is often better than one that
snaps at 768px.

**`respects-reduced-motion`** — A viewer who asks for less motion still has to be able to
read the section. Switch the motion off, do not hide the content.

**`nothing-parked-at-opacity-0`** — The one worth internalising. The intuitive way to build
a scroll reveal is to hide the element in CSS and let JavaScript show it. That makes a
permanent blank band out of any JS failure — and JS on a shared homepage fails for reasons
that have nothing to do with your snippet. Keep the CSS default visible; arm the hidden
state from the script, only for what is below the fold.

**`guarded-idempotent-iife`** — POCs paste twice, and other widgets share the page. The
root lookup with `if (!root) return;` stops the script running against a page that does
not contain the section; the prefixed `data-` flag stops a duplicate paste binding two
observers to the same elements.

## What the script cannot see

Passing all eight means the snippet will not break the page in the known ways. It says
nothing about whether the section is any good. These still need a human and a browser:

- Whether the layout holds at 320px, at 768px, and at 1440px
- Whether a seller's real image survives the crop (`object-fit`, aspect ratio)
- Whether the type scale reads as intended, or the headline sets as one thin ribbon
- Whether the reveal timing feels considered or twitchy
- Whether the copy is the seller's voice
- **Whether it collides with this seller's theme.** Prefixing makes collisions unlikely;
  only rendering it on the seller's own page proves it. That is the POC's Preview step,
  and the handoff should say so rather than imply the snippet is proven.

## Adding a check

Add it to `checks()` in the script as a `(name, bool, why)` tuple. Keep the `why` a
sentence about the failure it prevents, not a restatement of the rule — the message is
read by whoever has to fix the snippet, and knowing what breaks is what tells them how.
