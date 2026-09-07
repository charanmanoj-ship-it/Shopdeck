#!/usr/bin/env python3
"""Check a Shopdeck code_snippet_widget blob against the eight snippet rules.

Usage:
    python3 audit_snippet.py <file> [--prefix btc-]

Exits 0 when every check passes, 1 otherwise. The prefix is inferred from the
first class attribute when not given, which is usually what you want: the point
is that every class shares one prefix, whatever it is.

These are text checks, not a browser. They catch the rules that are cheap to get
wrong and expensive to discover after a seller's homepage is live (theme CSS
collisions, a blank band when JS fails, a CDN link that will not load). They
cannot tell you the section looks right — render it and look.
"""
import argparse
import re
import sys

CLASS_RE = re.compile(r'class\s*=\s*"([^"]*)"')


def infer_prefix(blob):
    m = CLASS_RE.search(blob)
    if not m:
        return None
    first = m.group(1).split()
    if not first:
        return None
    token = first[0]
    hit = re.match(r'^([a-z0-9]+[-_])', token)
    return hit.group(1) if hit else None


def unprefixed(blob, prefix):
    bad = []
    for m in CLASS_RE.finditer(blob):
        for cls in m.group(1).split():
            if not cls.startswith(prefix) and cls not in bad:
                bad.append(cls)
    return bad


def checks(blob, prefix):
    i_style = blob.find("<style")
    i_script = blob.find("<script")
    bad = unprefixed(blob, prefix) if prefix else ["(no class attributes found)"]

    return [
        ("order-markup-style-script",
         i_style > 0 and i_script > i_style,
         "Shopdeck renders the field top to bottom, so the styles have to land before the script runs."),
        ("classes-prefixed",
         prefix is not None and not bad,
         "Unprefixed classes let the seller's theme CSS reach inside the section: "
         + (", ".join(bad[:6]) if bad else "none")),
        ("no-external-assets",
         not re.search(r'<script[^>]+src=', blob, re.I)
         and not re.search(r'<link[^>]+stylesheet', blob, re.I)
         and not re.search(r'@import', blob, re.I)
         and not re.search(r'fonts\.googleapis', blob, re.I),
         "A snippet has no build step and no reliable way to load anything; fonts come from device stacks."),
        ("full-bleed-breakout",
         "100vw" in blob and re.search(r'50%\s*-\s*50vw', blob) is not None,
         "Without the breakout the band sits inside the theme's max-width container instead of running edge to edge."),
        ("adapts-across-widths",
         re.search(r'@media[^{]*\(min-width:', blob) is not None
         or re.search(r'clamp\(', blob) is not None,
         "One paste serves mobile and desktop; there is no second field for a mobile version. "
         "Either a min-width breakpoint or fluid clamp() sizing satisfies this."),
        ("respects-reduced-motion",
         "prefers-reduced-motion" in blob,
         "Viewers who ask for less motion still need to read the section."),
        ("nothing-parked-at-opacity-0",
         re.search(r'opacity:\s*0\s*[;}]', blob) is None,
         "If the CSS hides content until JS reveals it, a script failure leaves a blank band on the homepage."),
        ("guarded-idempotent-iife",
         re.search(r'if\s*\(\s*!\s*root\s*\)\s*return', blob) is not None
         and re.search(r'data-[a-z0-9_-]+', blob, re.I) is not None,
         "The POC may paste twice and other widgets share the page; bind once, touch only your own root."),
    ]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--prefix", default=None)
    args = ap.parse_args()

    blob = open(args.file, encoding="utf-8").read()
    prefix = args.prefix or infer_prefix(blob)
    results = checks(blob, prefix)

    print("prefix: %s" % (prefix or "NOT FOUND"))
    failed = 0
    for name, ok, why in results:
        print("%-4s %-30s %s" % ("pass" if ok else "FAIL", name, "" if ok else why))
        if not ok:
            failed += 1
    print("\n%d/%d checks pass" % (len(results) - failed, len(results)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
