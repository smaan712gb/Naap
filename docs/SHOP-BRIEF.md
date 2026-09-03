# SHOP-BRIEF — the tiered house

Reconciles the external merchandising brief (2026-09-03) with Naap's laws.
Where they conflicted, the decisions below won. Companion to
web/WEBSITE-BRIEF.md (visual constitution); this file governs
merchandising, catalog data, and brand voice.

## The diagnosis (adopted verbatim)

A flat grid showing $24 wash-and-wear beside $349 velvet reads bazaar
stall, not house. Luxury never mixes tiers on one page. Fourteen SKUs in
one grid feels empty; the same SKUs in three curated rooms feels
intentional and scarce.

## The three rooms (live)

| Tier | Cloth | Occasions | Ladder |
| --- | --- | --- | --- |
| **Everyday** | lawn, latha, wash & wear, khaddar, dhanak | daily, workwear | $24–38 |
| **Occasion** | embroidered lawn, boski 6lb/8lb, organza, wool blazer, kurta MTM | eid, nikkah, dinner | $54–349 |
| **Ceremonial** | raw silk, velvet, boski 12lb, jamawar, banarsi tissue, hand-zardozi | barat, walima, bridal, groom | $95–1,450 |

Anchor logic (adopted): the $1,450 hand-zardozi and $680 jamawar exist
partly to sell themselves and partly to make the $349 pieces feel
accessible. Boski gets the traditional pound ladder (6lb summer /
8lb classic / 12lb groom) — the grade system masters actually use.

The **Swatch Box** ($19, credited toward first order) is the ultra-MTM
standard for selling cloth remotely; ships ready-to-dispatch.

## Brand voice

- NEVER name other houses in customer-facing copy ("inspired by Fendi"
  is a trademark suit waiting to happen — blueprint rule 5 already
  banned it). Describe aesthetics: *unstructured Italian drape*,
  *Milanese shoulder*, *minimalist ceremonial*.
- Scarcity is named, not apologized for: "This season: twenty-one
  cloths." Limited reads luxury; sparse reads unfinished.
- **Specifications are the house voice.** We are a measurement company;
  publishing weight grade, drape class, gsm and loom facts is the most
  natural brand extension we have — and no Pakistani brand does it.
  Spec lines render on cards (weight_grade · drape · gsm).

## Provenance — the integrity line (amendment to the external brief)

The brief wants mill, city, loom type, weaver, weeks-to-weave per SKU.
Adopted as SCHEMA (`mill`, `mill_city`, `loom_type`, `story` on Fabric),
but **populated only from a real supplier's own statements**. A
"60-year-old shuttle loom in Faisalabad" that no one has seen is a
fabricated record and is banned regardless of how luxurious it sounds.
Until supplier relationships exist these fields stay empty and the UI
omits them. Generic textile facts (a velvet's structured drape, boski's
pound grades) are publishable; SKU-specific origin claims are not.

## Imagery depth

Target per SKU: macro weave, drape in raking light, folded bolt,
on-body. The studio (scripts/image_studio.py) generates all of it;
`images[]` on Fabric holds the extra views. Rollout: ceremonial tier
first (where depth sells), then occasion, then everyday.

## Configurator-first (phased)

The brief's best structural point: an MTM house sells combinations
(21 cloths × silhouettes × necklines × sleeves × daman), not cloth.
The full configurator already exists — in the app (garment, fit,
silhouette, neckline, sleeve, daman, pockets). Web phase 1: product
pages route to the app ("your measurements live there"). Web phase 2:
a browser configurator once orders justify it.

## Schema (Fabric model — live)

`tier`, `images[]`, `mill`, `mill_city`, `loom_type`, `story`,
`weight_grade`, `gsm`, `drape` (fluid|structured|crisp),
`swatch_available`. `/catalog?tier=` filters; tier tabs render
full-bleed room banners (tier-everyday/occasion/ceremonial on the CDN).

## Not adopted

- Separate routes (/cloth/everyday …): the shop is one deployable page;
  rooms are tabs with banner + filtered grid. Same effect, no routing
  infrastructure. Revisit at real traffic.
- 3-up desktop grid: the founder chose the full-bleed 4-up wall; kept.
- Invented provenance and paid placement of unverifiable claims: never.
