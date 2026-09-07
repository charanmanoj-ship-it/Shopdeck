# Section templates

Five shapes that cover most of what sellers ask for. Each one is a complete, audited blob: it has been run through `scripts/audit_snippet.py` and passes all eight checks as written.

Use them as a starting point, not a catalogue. Read the brief first — if the seller wants something none of these are, write it fresh against the contract in SKILL.md. Starting from the nearest template and reshaping it is usually faster than starting from nothing, because the reveal engine, the full-bleed breakout and the idempotency guard are already correct.

The tokens to substitute in every template: the class prefix (`btc-` here), the ground, ink and accent colours, the font stack, and the copy. The copy below is Bombay Textile's, used to show what real content does to the layout — replace all of it.

## Contents

- [Editorial statement](#editorial-statement) — One oversized line, hairline rule, staggered reveal. The WEAR THE SLOWER SIDE shape.
- [Story split](#story-split) — Image beside a block of narrative copy. For fabric, craft or founder stories.
- [Promise strip](#promise-strip) — Three or four short trust claims in a row, divided by hairlines. No numbering — they aren't a sequence.
- [Lookbook grid](#lookbook-grid) — Image tiles with captions. Two up on mobile, four across on desktop, slow zoom on hover.
- [Marquee strip](#marquee-strip) — Seamless scrolling announcement band. Pauses on hover, static when motion is reduced.

---

## Editorial statement

**When this is the right shape.** The seller has one thing to say and wants it said with weight — a philosophy, a positioning line, a reason the product costs what it costs. This is the shape the Bombay Textile “WEAR THE SLOWER SIDE.” section uses. Reach for it second or third down the homepage, after the hero, where a visitor is deciding whether to keep scrolling.

**Widget row name used here:** `WEAR THE SLOWER SIDE.`

**How it behaves.** Text rises 16px into place as the band enters view. The headline is capped at 20 characters wide so it breaks into two or three lines rather than running as one thin ribbon on a wide screen.

**Preview note to hand over:** A full-bleed band on #F5F2EC. The eyebrow sits in small tracked caps, then the headline breaks across two or three lines at roughly 6rem on desktop and 2.6rem on mobile, a #7A3B2E hairline under it, body copy held to about 46 characters, and an underlined link. Everything rises 16px into place as the band enters view — and is already legible if it is the first thing on screen.

```html
<!-- WEAR THE SLOWER SIDE. · Shopdeck code_snippet_widget -->
<!-- All classes prefixed btc- · no external scripts or stylesheets · mobile + desktop -->
<section class="btc-statement" aria-labelledby="btc-statement-title">
  <div class="btc-statement__inner">
    <p class="btc-statement__eyebrow btc-reveal">Bombay Textile — No. 04</p>
    <h2 class="btc-statement__title btc-reveal" id="btc-statement-title">Wear the slower side.</h2>
    <span class="btc-statement__rule btc-reveal" aria-hidden="true"></span>
    <p class="btc-statement__body btc-reveal">Handloom cotton, woven in Bhuj on pit looms that move at the pace of a pair of hands. Six metres a day, not six hundred. You can feel the difference in the drape.</p>
    <a class="btc-statement__cta btc-reveal" href="/collections/handloom">See the weave</a>
  </div>
</section>

<style>
.btc-statement{width:100vw;margin-left:calc(50% - 50vw);margin-right:calc(50% - 50vw);background:#F5F2EC;color:#1A1A18;font-family:Georgia, "Times New Roman", Times, serif;padding:clamp(56px,13vw,132px) 20px;overflow:hidden}
.btc-statement__inner{max-width:1040px;margin:0 auto}
.btc-statement__eyebrow{margin:0 0 clamp(18px,4vw,30px);font-size:11px;letter-spacing:.24em;text-transform:uppercase;opacity:.62}
.btc-statement__title{margin:0;font-weight:400;font-size:clamp(2.5rem,8.4vw,6rem);line-height:.98;letter-spacing:-.025em;text-wrap:balance;max-width:20ch}
.btc-statement__rule{display:block;width:clamp(64px,12vw,132px);height:1px;background:#7A3B2E;margin:clamp(26px,5vw,44px) 0}
.btc-statement__body{margin:0;font-size:clamp(.95rem,1.5vw,1.0625rem);line-height:1.72;max-width:46ch;opacity:.78}
.btc-statement__cta{display:inline-block;margin-top:clamp(22px,4vw,34px);font-size:11.5px;letter-spacing:.18em;text-transform:uppercase;color:#7A3B2E;text-decoration:underline;text-underline-offset:6px;text-decoration-thickness:1px}
.btc-statement__cta:hover{text-underline-offset:9px}
.btc-reveal{transition:opacity .75s ease,transform .75s cubic-bezier(.2,.7,.2,1);transition-delay:calc(var(--btc-i, 0) * 90ms)}
.btc-statement[data-btc-anim="armed"] .btc-reveal{opacity:.001;transform:translateY(16px)}
.btc-statement .btc-reveal.btc-is-active{opacity:1;transform:none}
@media (prefers-reduced-motion: reduce){.btc-statement .btc-reveal{opacity:1 !important;transform:none !important;transition:none !important}}
</style>

<script>
(function(){
  var root = document.querySelector('.btc-statement');
  if (!root) return;
  if (root.getAttribute('data-btc-ready') === '1') return;   /* paste twice, bind once */
  root.setAttribute('data-btc-ready', '1');

  var items = root.querySelectorAll('.btc-reveal');
  if (!items.length) return;

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var show = function(el){ el.classList.add('btc-is-active'); };

  if (reduce || !('IntersectionObserver' in window)) {
    for (var i = 0; i < items.length; i++) show(items[i]);
    return;
  }

  /* Arm only what is below the fold, so nothing above it ever flashes blank. */
  var pending = [];
  for (var j = 0; j < items.length; j++) {
    var el = items[j];
    el.style.setProperty('--btc-i', String(j % 6));
    if (el.getBoundingClientRect().top < window.innerHeight * 0.9) show(el);
    else pending.push(el);
  }
  if (!pending.length) return;
  root.setAttribute('data-btc-anim', 'armed');

  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if (!entry.isIntersecting) return;
      show(entry.target);
      io.unobserve(entry.target);
    });
  }, { threshold: 0.18, rootMargin: '0px 0px -8% 0px' });

  pending.forEach(function(el){ io.observe(el); });
})();
</script>
```

---

## Story split

**When this is the right shape.** Provenance, craft, or founder narrative — anything where one image and a paragraph do more together than either alone. Two of these alternating (image left, then image right) reads as a spread; three in a row reads as a slideshow nobody asked for.

**Widget row name used here:** `THE FABRIC STORY`

**How it behaves.** The image is fixed at 4:5 with `object-fit: cover`, so a seller pasting a landscape photo gets a sensible crop instead of a broken column. `--flip` swaps the sides on desktop only; mobile always leads with the image.

**Preview note to hand over:** Two columns on desktop — a 4:5 image on the left, copy on the other side, vertically centred; a single stacked column on mobile with the image first. Ground #F5F2EC, eyebrow and link in #7A3B2E. The copy column rises into view; the image holds still.

```html
<!-- THE FABRIC STORY · Shopdeck code_snippet_widget -->
<!-- All classes prefixed btc- · no external scripts or stylesheets · mobile + desktop -->
<section class="btc-story" aria-labelledby="btc-story-title">
  <figure class="btc-story__media">
    <img class="btc-story__img" src="REPLACE-fabric-loom.jpg" alt="Pit loom, Bhuj" loading="lazy" decoding="async">
    <figcaption class="btc-story__caption">Pit loom, Bhuj</figcaption>
  </figure>
  <div class="btc-story__copy">
    <p class="btc-story__eyebrow btc-reveal">The fabric</p>
    <h2 class="btc-story__title btc-reveal" id="btc-story-title">Kala cotton, grown without a drop of irrigation.</h2>
    <p class="btc-story__body btc-reveal">Indigenous to Kutch, rain-fed, and short-staple — which is exactly why it spins into a yarn with texture instead of a flat, uniform thread. The bolls are hand-picked between November and February. What reaches the loom has never met a chemical defoliant.</p>
    <a class="btc-story__cta btc-reveal" href="/pages/our-fabric">Read the full story</a>
  </div>
</section>

<style>
.btc-story{width:100vw;margin-left:calc(50% - 50vw);margin-right:calc(50% - 50vw);background:#F5F2EC;color:#1A1A18;font-family:Georgia, "Times New Roman", Times, serif;display:grid;grid-template-columns:1fr;gap:clamp(22px,5vw,54px);align-items:center;padding:clamp(40px,8vw,90px) 20px}
.btc-story__media{margin:0;min-width:0}
.btc-story__img{display:block;width:100%;height:auto;aspect-ratio:4/5;object-fit:cover;background:rgba(0,0,0,.06)}
.btc-story__caption{margin-top:10px;font-size:10.5px;letter-spacing:.16em;text-transform:uppercase;opacity:.55}
.btc-story__copy{min-width:0;max-width:52ch}
.btc-story__eyebrow{margin:0 0 14px;font-size:10.5px;letter-spacing:.22em;text-transform:uppercase;color:#7A3B2E}
.btc-story__title{margin:0 0 16px;font-weight:400;font-size:clamp(1.75rem,4.4vw,2.9rem);line-height:1.08;letter-spacing:-.02em;text-wrap:balance}
.btc-story__body{margin:0;font-size:clamp(.9375rem,1.4vw,1.0625rem);line-height:1.78;opacity:.8}
.btc-story__cta{display:inline-block;margin-top:24px;font-size:11px;letter-spacing:.18em;text-transform:uppercase;color:#7A3B2E;text-decoration:underline;text-underline-offset:6px}
@media (min-width:820px){
  .btc-story{grid-template-columns:minmax(0,1fr) minmax(0,1fr);padding-left:clamp(24px,6vw,88px);padding-right:clamp(24px,6vw,88px)}
  .btc-story--flip .btc-story__media{order:2}
  .btc-story--flip .btc-story__copy{order:1;justify-self:end}
}
.btc-reveal{transition:opacity .75s ease,transform .75s cubic-bezier(.2,.7,.2,1);transition-delay:calc(var(--btc-i, 0) * 90ms)}
.btc-story[data-btc-anim="armed"] .btc-reveal{opacity:.001;transform:translateY(16px)}
.btc-story .btc-reveal.btc-is-active{opacity:1;transform:none}
@media (prefers-reduced-motion: reduce){.btc-story .btc-reveal{opacity:1 !important;transform:none !important;transition:none !important}}
</style>

<script>
(function(){
  var root = document.querySelector('.btc-story');
  if (!root) return;
  if (root.getAttribute('data-btc-ready') === '1') return;   /* paste twice, bind once */
  root.setAttribute('data-btc-ready', '1');

  var items = root.querySelectorAll('.btc-reveal');
  if (!items.length) return;

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var show = function(el){ el.classList.add('btc-is-active'); };

  if (reduce || !('IntersectionObserver' in window)) {
    for (var i = 0; i < items.length; i++) show(items[i]);
    return;
  }

  /* Arm only what is below the fold, so nothing above it ever flashes blank. */
  var pending = [];
  for (var j = 0; j < items.length; j++) {
    var el = items[j];
    el.style.setProperty('--btc-i', String(j % 6));
    if (el.getBoundingClientRect().top < window.innerHeight * 0.9) show(el);
    else pending.push(el);
  }
  if (!pending.length) return;
  root.setAttribute('data-btc-anim', 'armed');

  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if (!entry.isIntersecting) return;
      show(entry.target);
      io.unobserve(entry.target);
    });
  }, { threshold: 0.18, rootMargin: '0px 0px -8% 0px' });

  pending.forEach(function(el){ io.observe(el); });
})();
</script>
```

---

## Promise strip

**When this is the right shape.** The three or four things that answer “why buy here and not there”. Deliberately unnumbered: these are simultaneous guarantees, not a sequence, and numbering them would tell the reader something false about their order.

**Widget row name used here:** `WHY BOMBAY TEXTILE`

**How it behaves.** Dashed dividers between stacked items on mobile become 1px vertical rules between columns on desktop. The column count is generated from how many items you pass, so four items give four columns and three give three.

**Preview note to hand over:** A quiet band of 4 claims. Stacked with dashed dividers on mobile, side by side in 4 equal columns on desktop with 1px vertical rules between them. Each claim leads with a small #7A3B2E diamond, a short bold label, then one line of detail. Reveals as a group, staggered left to right.

```html
<!-- WHY BOMBAY TEXTILE · Shopdeck code_snippet_widget -->
<!-- All classes prefixed btc- · no external scripts or stylesheets · mobile + desktop -->
<section class="btc-promise" aria-label="What you can count on">
  <p class="btc-promise__eyebrow btc-reveal">What you can count on</p>
  <ul class="btc-promise__list">
    <li class="btc-promise__item btc-reveal">
      <span class="btc-promise__mark" aria-hidden="true">&#9670;</span>
      <span class="btc-promise__label">Woven, not printed</span>
      <span class="btc-promise__detail">Every metre comes off a pit loom in Kutch.</span>
    </li>
    <li class="btc-promise__item btc-reveal">
      <span class="btc-promise__mark" aria-hidden="true">&#9670;</span>
      <span class="btc-promise__label">48-hour dispatch</span>
      <span class="btc-promise__detail">Ordered before 2pm on a weekday, it ships the same day.</span>
    </li>
    <li class="btc-promise__item btc-reveal">
      <span class="btc-promise__mark" aria-hidden="true">&#9670;</span>
      <span class="btc-promise__label">7-day returns</span>
      <span class="btc-promise__detail">Unworn, tags on, no questions and no restocking fee.</span>
    </li>
    <li class="btc-promise__item btc-reveal">
      <span class="btc-promise__mark" aria-hidden="true">&#9670;</span>
      <span class="btc-promise__label">Speak to a human</span>
      <span class="btc-promise__detail">WhatsApp us on the number in the footer, 10am to 7pm.</span>
    </li>
  </ul>
</section>

<style>
.btc-promise{width:100vw;margin-left:calc(50% - 50vw);margin-right:calc(50% - 50vw);background:#F5F2EC;color:#1A1A18;font-family:Georgia, "Times New Roman", Times, serif;padding:clamp(34px,6vw,64px) 20px}
.btc-promise__eyebrow{margin:0 auto clamp(22px,4vw,38px);max-width:1120px;font-size:10.5px;letter-spacing:.22em;text-transform:uppercase;opacity:.6;text-align:center}
.btc-promise__list{list-style:none;margin:0 auto;padding:0;max-width:1120px;display:grid;grid-template-columns:1fr;gap:0}
.btc-promise__item{display:grid;grid-template-columns:auto 1fr;grid-template-areas:'mark label' '. detail';column-gap:11px;row-gap:4px;padding:16px 0;border-top:1px dashed rgba(0,0,0,.14)}
.btc-promise__list > .btc-promise__item:first-child{border-top:0}
.btc-promise__mark{grid-area:mark;color:#7A3B2E;font-size:8px;line-height:1.9}
.btc-promise__label{grid-area:label;font-size:13px;font-weight:600;letter-spacing:.01em}
.btc-promise__detail{grid-area:detail;font-size:12.5px;line-height:1.6;opacity:.7;max-width:34ch}
@media (min-width:760px){
  .btc-promise__list{grid-template-columns:repeat(4,minmax(0,1fr))}
  .btc-promise__item{padding:4px clamp(16px,3vw,30px);border-top:0;border-left:1px solid rgba(0,0,0,.13)}
  .btc-promise__list > .btc-promise__item:first-child{border-left:0;padding-left:0}
}
.btc-reveal{transition:opacity .75s ease,transform .75s cubic-bezier(.2,.7,.2,1);transition-delay:calc(var(--btc-i, 0) * 90ms)}
.btc-promise[data-btc-anim="armed"] .btc-reveal{opacity:.001;transform:translateY(16px)}
.btc-promise .btc-reveal.btc-is-active{opacity:1;transform:none}
@media (prefers-reduced-motion: reduce){.btc-promise .btc-reveal{opacity:1 !important;transform:none !important;transition:none !important}}
</style>

<script>
(function(){
  var root = document.querySelector('.btc-promise');
  if (!root) return;
  if (root.getAttribute('data-btc-ready') === '1') return;   /* paste twice, bind once */
  root.setAttribute('data-btc-ready', '1');

  var items = root.querySelectorAll('.btc-reveal');
  if (!items.length) return;

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var show = function(el){ el.classList.add('btc-is-active'); };

  if (reduce || !('IntersectionObserver' in window)) {
    for (var i = 0; i < items.length; i++) show(items[i]);
    return;
  }

  /* Arm only what is below the fold, so nothing above it ever flashes blank. */
  var pending = [];
  for (var j = 0; j < items.length; j++) {
    var el = items[j];
    el.style.setProperty('--btc-i', String(j % 6));
    if (el.getBoundingClientRect().top < window.innerHeight * 0.9) show(el);
    else pending.push(el);
  }
  if (!pending.length) return;
  root.setAttribute('data-btc-anim', 'armed');

  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if (!entry.isIntersecting) return;
      show(entry.target);
      io.unobserve(entry.target);
    });
  }, { threshold: 0.18, rootMargin: '0px 0px -8% 0px' });

  pending.forEach(function(el){ io.observe(el); });
})();
</script>
```

---

## Lookbook grid

**When this is the right shape.** A curated set of looks or a seasonal edit, where the images are the argument and the captions are only labels. Four or eight images sit well on the desktop grid; five or seven leave a hole in the last row.

**Widget row name used here:** `THE SUMMER EDIT`

**How it behaves.** Hover scales the image 3% inside a fixed frame, so the grid never reflows under the cursor. Captions are labels, not sentences — keep them to two or three words.

**Preview note to hand over:** A centred heading over 4 portrait tiles at 3:4 — two per row on mobile, four across from 900px. Captions sit under each tile in small tracked caps; hovering scales the image 3% behind a fixed frame, so the grid never shifts. Tiles fade up in pairs as the row enters view.

```html
<!-- THE SUMMER EDIT · Shopdeck code_snippet_widget -->
<!-- All classes prefixed btc- · no external scripts or stylesheets · mobile + desktop -->
<section class="btc-lookbook" aria-labelledby="btc-lookbook-title">
  <header class="btc-lookbook__head">
    <p class="btc-lookbook__eyebrow btc-reveal">Lookbook</p>
    <h2 class="btc-lookbook__title btc-reveal" id="btc-lookbook-title">Six pieces for a Bombay April.</h2>
  </header>
  <div class="btc-lookbook__grid">
    <figure class="btc-lookbook__tile btc-reveal">
      <span class="btc-lookbook__frame">
        <img class="btc-lookbook__img" src="REPLACE-look-01.jpg" alt="Kala cotton kurta" loading="lazy" decoding="async">
      </span>
      <figcaption class="btc-lookbook__caption">Kala cotton kurta</figcaption>
    </figure>
    <figure class="btc-lookbook__tile btc-reveal">
      <span class="btc-lookbook__frame">
        <img class="btc-lookbook__img" src="REPLACE-look-02.jpg" alt="Indigo wrap skirt" loading="lazy" decoding="async">
      </span>
      <figcaption class="btc-lookbook__caption">Indigo wrap skirt</figcaption>
    </figure>
    <figure class="btc-lookbook__tile btc-reveal">
      <span class="btc-lookbook__frame">
        <img class="btc-lookbook__img" src="REPLACE-look-03.jpg" alt="Mul cotton shirt" loading="lazy" decoding="async">
      </span>
      <figcaption class="btc-lookbook__caption">Mul cotton shirt</figcaption>
    </figure>
    <figure class="btc-lookbook__tile btc-reveal">
      <span class="btc-lookbook__frame">
        <img class="btc-lookbook__img" src="REPLACE-look-04.jpg" alt="Handloom dupatta" loading="lazy" decoding="async">
      </span>
      <figcaption class="btc-lookbook__caption">Handloom dupatta</figcaption>
    </figure>
  </div>
  <a class="btc-lookbook__cta btc-reveal" href="/collections/summer">Shop the edit</a>
</section>

<style>
.btc-lookbook{width:100vw;margin-left:calc(50% - 50vw);margin-right:calc(50% - 50vw);background:#F5F2EC;color:#1A1A18;font-family:Georgia, "Times New Roman", Times, serif;padding:clamp(44px,8vw,86px) 16px;text-align:center}
.btc-lookbook__head{max-width:640px;margin:0 auto clamp(26px,5vw,44px)}
.btc-lookbook__eyebrow{margin:0 0 10px;font-size:10.5px;letter-spacing:.22em;text-transform:uppercase;color:#7A3B2E}
.btc-lookbook__title{margin:0;font-weight:400;font-size:clamp(1.6rem,4vw,2.5rem);line-height:1.12;letter-spacing:-.02em;text-wrap:balance}
.btc-lookbook__grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:clamp(10px,2vw,20px);max-width:1240px;margin:0 auto}
.btc-lookbook__tile{margin:0;min-width:0;text-align:left}
.btc-lookbook__frame{display:block;overflow:hidden;background:rgba(0,0,0,.06)}
.btc-lookbook__img{display:block;width:100%;height:auto;aspect-ratio:3/4;object-fit:cover;transition:transform .8s cubic-bezier(.2,.7,.2,1)}
.btc-lookbook__tile:hover .btc-lookbook__img{transform:scale(1.03)}
.btc-lookbook__caption{margin-top:9px;font-size:10.5px;letter-spacing:.15em;text-transform:uppercase;opacity:.62}
.btc-lookbook__cta{display:inline-block;margin-top:clamp(26px,5vw,42px);font-size:11px;letter-spacing:.18em;text-transform:uppercase;color:#7A3B2E;text-decoration:underline;text-underline-offset:6px}
@media (min-width:900px){.btc-lookbook__grid{grid-template-columns:repeat(4,minmax(0,1fr))}}
@media (prefers-reduced-motion: reduce){.btc-lookbook__img{transition:none}.btc-lookbook__tile:hover .btc-lookbook__img{transform:none}}
.btc-reveal{transition:opacity .75s ease,transform .75s cubic-bezier(.2,.7,.2,1);transition-delay:calc(var(--btc-i, 0) * 90ms)}
.btc-lookbook[data-btc-anim="armed"] .btc-reveal{opacity:.001;transform:translateY(16px)}
.btc-lookbook .btc-reveal.btc-is-active{opacity:1;transform:none}
@media (prefers-reduced-motion: reduce){.btc-lookbook .btc-reveal{opacity:1 !important;transform:none !important;transition:none !important}}
</style>

<script>
(function(){
  var root = document.querySelector('.btc-lookbook');
  if (!root) return;
  if (root.getAttribute('data-btc-ready') === '1') return;   /* paste twice, bind once */
  root.setAttribute('data-btc-ready', '1');

  var items = root.querySelectorAll('.btc-reveal');
  if (!items.length) return;

  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var show = function(el){ el.classList.add('btc-is-active'); };

  if (reduce || !('IntersectionObserver' in window)) {
    for (var i = 0; i < items.length; i++) show(items[i]);
    return;
  }

  /* Arm only what is below the fold, so nothing above it ever flashes blank. */
  var pending = [];
  for (var j = 0; j < items.length; j++) {
    var el = items[j];
    el.style.setProperty('--btc-i', String(j % 6));
    if (el.getBoundingClientRect().top < window.innerHeight * 0.9) show(el);
    else pending.push(el);
  }
  if (!pending.length) return;
  root.setAttribute('data-btc-anim', 'armed');

  var io = new IntersectionObserver(function(entries){
    entries.forEach(function(entry){
      if (!entry.isIntersecting) return;
      show(entry.target);
      io.unobserve(entry.target);
    });
  }, { threshold: 0.18, rootMargin: '0px 0px -8% 0px' });

  pending.forEach(function(el){ io.observe(el); });
})();
</script>
```

---

## Marquee strip

**When this is the right shape.** Operational facts that every visitor should see but none should have to hunt for: shipping thresholds, return windows, dispatch times. It earns its motion because the content is a list with no beginning or end. Do not put a single message in a marquee — a static band says it better.

**Widget row name used here:** `STORE TICKER`

**How it behaves.** Two identical tracks scroll side by side so the loop has no seam. The second one carries `aria-hidden` because a screen reader should hear the phrases once. The script pauses the animation while the band is off screen, which matters on a long homepage.

**Preview note to hand over:** A thin band, #1A1A18 on #7A3B2E, running 4 phrases right-to-left in a seamless loop at 28s per pass, separated by a small diamond. It pauses when a cursor rests on it. With reduced motion on it becomes a centred static row and wraps on narrow screens.

```html
<!-- STORE TICKER · Shopdeck code_snippet_widget -->
<!-- All classes prefixed btc- · no external scripts or stylesheets · mobile + desktop -->
<section class="btc-marquee" aria-label="Store announcements">
  <div class="btc-marquee__viewport">
    <div class="btc-marquee__track">
      <span class="btc-marquee__item">Free shipping over Rs. 1,499<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
      <span class="btc-marquee__item">7-day easy returns<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
      <span class="btc-marquee__item">Handloom, not powerloom<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
      <span class="btc-marquee__item">Ships in 48 hours from Ahmedabad<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
    </div>
    <div class="btc-marquee__track" aria-hidden="true">
      <span class="btc-marquee__item">Free shipping over Rs. 1,499<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
      <span class="btc-marquee__item">7-day easy returns<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
      <span class="btc-marquee__item">Handloom, not powerloom<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
      <span class="btc-marquee__item">Ships in 48 hours from Ahmedabad<span class="btc-marquee__dot" aria-hidden="true">&#9670;</span></span>
    </div>
  </div>
</section>

<style>
.btc-marquee{width:100vw;margin-left:calc(50% - 50vw);margin-right:calc(50% - 50vw);background:#7A3B2E;color:#1A1A18;font-family:Georgia, "Times New Roman", Times, serif;padding:13px 0;overflow:hidden}
.btc-marquee__viewport{display:flex;width:max-content}
.btc-marquee__track{display:flex;align-items:center;flex:none;animation:btc-marquee-scroll 28s linear infinite}
.btc-marquee:hover .btc-marquee__track{animation-play-state:paused}
.btc-marquee__item{display:inline-flex;align-items:center;gap:clamp(20px,4vw,38px);padding-right:clamp(20px,4vw,38px);font-size:11.5px;letter-spacing:.2em;text-transform:uppercase;white-space:nowrap}
.btc-marquee__dot{font-size:7px;opacity:.5;transform:translateY(-1px)}
@keyframes btc-marquee-scroll{from{transform:translateX(0)}to{transform:translateX(-100%)}}
@media (prefers-reduced-motion: reduce){
  .btc-marquee__viewport{width:100%;flex-wrap:wrap;justify-content:center}
  .btc-marquee__track{animation:none;flex-wrap:wrap;justify-content:center;row-gap:6px}
  .btc-marquee__viewport > .btc-marquee__track:last-child{display:none}
  .btc-marquee__item{white-space:normal}
}
</style>

<script>
(function(){
  var root = document.querySelector('.btc-marquee');
  if (!root) return;
  if (root.getAttribute('data-btc-ready') === '1') return;
  root.setAttribute('data-btc-ready', '1');

  /* Pause the loop while the band is off screen — no repaint cost on long pages. */
  if (!('IntersectionObserver' in window)) return;
  var tracks = root.querySelectorAll('.btc-marquee__track');
  var io = new IntersectionObserver(function(entries){
    var on = entries[0] && entries[0].isIntersecting;
    for (var i = 0; i < tracks.length; i++) {
      tracks[i].style.animationPlayState = on ? 'running' : 'paused';
    }
  }, { threshold: 0 });
  io.observe(root);
})();
</script>
```

