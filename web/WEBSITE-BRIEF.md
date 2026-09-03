# getnaap.com — design constitution

Every change to `web/landing/` answers to this document. It reconciles the
external design brief (2026-09-03) with Naap's actual business; where they
disagreed, the decisions below won.

## The spine

**Restraint on the brand surface, warmth on the commerce surface.**
The landing page follows the Armani/Prada register: near-black green, vast
negative space, one CTA, didone display type, square geometry. The shop
keeps a richer, denser grid — Fendi's own split (editorial home, dense
product listing). The "choose one spine" ultimatum was rejected: our
audiences span Milan restraint AND Lahore abundance, and the two surfaces
serve them separately.

## Tokens (both pages)

```
--ink:#14110F  --bone:#F4F2ED  --stone:#8C877D  --line:#DCD8D0
--green:#0C1F19 (brand root, near-black)  --accent:#8C7A4B (muted brass)
display: Bodoni Moda (never below ~1.4rem — didone hairlines break on
         low-DPI Pakistani Android panels; small text is always Inter)
sans: Inter
```

## Hard rules

- No emoji, anywhere.
- No border-radius on layout elements (functional chips/round colour
  swatches exempt).
- No box-shadow. Hairlines (`--line`) or whitespace instead.
- No brightness-filter hovers; underline/border transitions only.
- One motion curve: `cubic-bezier(0.16,1,0.3,1)`, 900ms, reveal =
  24px translateY + fade via IntersectionObserver (threshold .15),
  disabled under `prefers-reduced-motion`.
- Hero: full-bleed media, 100svh, type bottom-left, H1 of 4–7 words,
  overlay never heavier than rgba(20,17,15,.28), exactly one link.
- Commercial mechanics (APK sideloading, TestFlight steps) live on
  /get.html — never on the front page. But a darzi on an Infinix must
  still reach the APK in two taps: Home → Get the app → Download.

## Urdu typography (the differentiator)

- Display Urdu (brand mark, hero line): **Noto Nastaliq Urdu**, loaded
  with `&text=` subsetting (full face ~1MB — never load it whole).
- Body Urdu (paragraphs, tailor block): **Noto Naskh Arabic**.
  Nastaliq at body sizes is unreadable; Naskh at display sizes is bland.

## Imagery

All photography comes from the in-house studio
(`scripts/image_studio.py`, Gemini): campaign stills (hero-silk,
hero-chalk, hero-shears), garment worn/flat/fit-variant shots — reviewed
by the founder before publish, served from getnaap.com/img/ (CloudFront).
No stock dependencies, no model releases, no brand resemblance, no logos.
The "no footage = no restraint" dependency in the external brief is void:
stills are prompts, not shoots. A film loop (8–12s, ≤3MB, AV1/WebM +
H.264 fallback) can be added later behind the adaptive gate below.

## Pakistan performance rules

- Hero stills ≤ ~150KB JPEG; catalog images ≤ ~200KB.
- When video ships: poster-only below 4G / saveData / reduced-motion —
  `navigator.connection.effectiveType` gate, exactly as the brief specs.
- Fonts subset where possible; never block render on Nastaliq.

## Shop grid (the §8 pattern, already live)

Flat cards, no borders/shadows; portrait crops; name + price in small
type below the image; hover = flat garment comes alive on the model
(Atelier), fit chips pin fitted/regular/loose; tabs All/New In/Atelier/
Women/Men; colour chips; material + sort selects. Size filters are
answered by measurement, not inventory — the app shows the client's own
measured size instead of a size wall.
