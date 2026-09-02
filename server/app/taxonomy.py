"""Catalog taxonomy — the customer-facing browse/filter structure.

Sourced from the official-catalog review of 2026-09-02 (SAPPHIRE, Khaadi,
Gul Ahmed, J., Republic, Faiza Saqlain, et al.). Design rules:

- Garment type, fabric, season, occasion, and stitching option are SEPARATE
  axes: one lawn suit can appear under Summer, Workwear, and Unstitched
  while remaining a single product row.
- The shopping fabric LABEL (what the customer knows: "Wash & Wear",
  "Boski") is stored separately from disclosed fiber composition — Boski in
  particular does not establish silk content (J.'s own Boski lists
  "Blended").
- Everything customer-visible is bilingual EN/UR.

Pure data — no logic, no LLM. A merchandiser can review this file line by
line the way a master tailor reviews the ease tables.
"""

from __future__ import annotations

AUDIENCES = [
    {"id": "women", "en": "Women", "ur": "خواتین"},
    {"id": "men", "en": "Men", "ur": "حضرات"},
]

CATEGORIES = [
    # ---- Women ----
    {"id": "w-unstitched", "audience": "women", "en": "Unstitched",
     "ur": "بغیر سلا کپڑا",
     "subs": [
         {"id": "shirt-only", "en": "Shirt-only fabric", "ur": "صرف قمیض کا کپڑا"},
         {"id": "two-piece", "en": "Two-piece sets", "ur": "دو پیس"},
         {"id": "three-piece", "en": "Three-piece sets", "ur": "تین پیس"},
         {"id": "larger-sets", "en": "Larger sets", "ur": "بڑے سیٹ"},
         {"id": "by-meter", "en": "Fabric by meter/yard", "ur": "میٹر/گز کے حساب سے"},
     ]},
    {"id": "w-everyday-rtw", "audience": "women", "en": "Everyday Ready to Wear",
     "ur": "روزمرہ تیار ملبوسات",
     "subs": [
         {"id": "kurtas", "en": "Kurtas", "ur": "کرتے"},
         {"id": "kurtis", "en": "Kurtis", "ur": "کرتیاں"},
         {"id": "shirts", "en": "Shirts", "ur": "شرٹس"},
         {"id": "shalwar-kameez", "en": "Shalwar kameez", "ur": "شلوار قمیض"},
         {"id": "kurta-trouser", "en": "Kurta & trouser sets", "ur": "کرتا پتلون سیٹ"},
         {"id": "co-ord", "en": "Co-ord sets", "ur": "کو-آرڈ سیٹ"},
     ]},
    {"id": "w-luxury-pret", "audience": "women", "en": "Luxury Pret",
     "ur": "لگژری پریٹ",
     "subs": [
         {"id": "formal-shirts", "en": "Formal shirts", "ur": "فارمل شرٹس"},
         {"id": "embroidered-sets", "en": "Embroidered sets", "ur": "کڑھائی والے سیٹ"},
         {"id": "embellished", "en": "Embellished outfits", "ur": "آرائشی ملبوسات"},
         {"id": "kaftans", "en": "Kaftans", "ur": "کفتان"},
         {"id": "jackets", "en": "Jackets", "ur": "جیکٹس"},
         {"id": "separates", "en": "Matching separates", "ur": "علیحدہ جوڑ"},
     ]},
    {"id": "w-bridal", "audience": "women", "en": "Wedding & Bridal",
     "ur": "شادی اور عروسی",
     "subs": [
         {"id": "lehenga-choli", "en": "Lehenga choli", "ur": "لہنگا چولی"},
         {"id": "gharara", "en": "Gharara sets", "ur": "غرارہ"},
         {"id": "sharara", "en": "Sharara sets", "ur": "شرارہ"},
         {"id": "pishwas", "en": "Pishwas", "ur": "پشواز"},
         {"id": "anarkali", "en": "Anarkali", "ur": "انارکلی"},
         {"id": "saree", "en": "Sarees", "ur": "ساڑھیاں"},
         {"id": "maxi-gown", "en": "Maxi dresses & gowns", "ur": "میکسی اور گاؤن"},
     ]},
    {"id": "w-bottoms", "audience": "women", "en": "Bottoms", "ur": "بوٹمز",
     "subs": [
         {"id": "straight-trousers", "en": "Straight trousers", "ur": "سیدھی پتلون"},
         {"id": "cigarette-pants", "en": "Cigarette pants", "ur": "سگریٹ پینٹس"},
         {"id": "wide-leg", "en": "Wide-leg pants", "ur": "کھلی پتلون"},
         {"id": "culottes", "en": "Culottes", "ur": "کیولاٹس"},
         {"id": "flared", "en": "Flared pants", "ur": "فلیئرڈ پینٹس"},
         {"id": "shalwar", "en": "Traditional shalwars", "ur": "روایتی شلواریں"},
         {"id": "tulip-shalwar", "en": "Tulip shalwars", "ur": "ٹیولپ شلوار"},
         {"id": "farshi-shalwar", "en": "Farshi shalwars", "ur": "فرشی شلوار"},
         {"id": "churidar", "en": "Churidars", "ur": "چوڑی دار"},
     ]},
    {"id": "w-dupatta-shawl", "audience": "women", "en": "Dupattas & Shawls",
     "ur": "دوپٹے اور شالیں",
     "subs": [
         {"id": "printed-dupatta", "en": "Printed dupattas", "ur": "پرنٹڈ دوپٹے"},
         {"id": "embroidered-dupatta", "en": "Embroidered dupattas", "ur": "کڑھائی والے دوپٹے"},
         {"id": "formal-dupatta", "en": "Formal dupattas", "ur": "فارمل دوپٹے"},
         {"id": "winter-shawl", "en": "Winter shawls", "ur": "سردیوں کی شالیں"},
         {"id": "stole", "en": "Stoles", "ur": "اسٹول"},
     ]},
    {"id": "w-modest", "audience": "women", "en": "Modest Wear", "ur": "حیا لباس",
     "subs": [
         {"id": "abaya", "en": "Abayas", "ur": "عبایا"},
         {"id": "hijab", "en": "Hijabs", "ur": "حجاب"},
         {"id": "modest-dress", "en": "Modest dresses", "ur": "باحیا لباس"},
     ]},
    {"id": "w-jackets-kotis", "audience": "women", "en": "Jackets & Kotis",
     "ur": "جیکٹس اور کوٹیاں",
     "subs": [
         {"id": "casual-jacket", "en": "Casual jackets", "ur": "کیژول جیکٹس"},
         {"id": "embroidered-koti", "en": "Embroidered kotis", "ur": "کڑھائی والی کوٹیاں"},
         {"id": "formal-layer", "en": "Formal layering pieces", "ur": "فارمل اوپری ملبوسات"},
     ]},
    # ---- Men ----
    {"id": "m-unstitched", "audience": "men", "en": "Unstitched",
     "ur": "بغیر سلا کپڑا",
     "subs": [
         {"id": "sk-fabric", "en": "Shalwar-kameez fabric cuts", "ur": "شلوار قمیض کا کپڑا"},
         {"id": "kurta-fabric", "en": "Kurta fabric", "ur": "کرتے کا کپڑا"},
         {"id": "suiting", "en": "Suiting fabric", "ur": "سوٹنگ کا کپڑا"},
         {"id": "by-meter", "en": "Fabric by meter/yard", "ur": "میٹر/گز کے حساب سے"},
     ]},
    {"id": "m-traditional", "audience": "men", "en": "Traditional Sets",
     "ur": "روایتی جوڑے",
     "subs": [
         {"id": "shalwar-kameez", "en": "Shalwar kameez", "ur": "شلوار قمیض"},
         {"id": "kurta-trouser", "en": "Kurta & trouser sets", "ur": "کرتا پتلون"},
         {"id": "kurta-pajama", "en": "Kurta & pajama sets", "ur": "کرتا پاجامہ"},
         {"id": "three-piece-waistcoat", "en": "Three-piece with waistcoat",
          "ur": "تین پیس مع واسکٹ"},
     ]},
    {"id": "m-kurtas", "audience": "men", "en": "Kurtas", "ur": "کرتے",
     "subs": [
         {"id": "plain", "en": "Plain kurtas", "ur": "سادہ کرتے"},
         {"id": "embroidered", "en": "Embroidered kurtas", "ur": "کڑھائی والے کرتے"},
         {"id": "textured", "en": "Textured kurtas", "ur": "بناوٹ والے کرتے"},
         {"id": "short", "en": "Short kurtas", "ur": "چھوٹے کرتے"},
     ]},
    {"id": "m-wedding", "audience": "men", "en": "Waistcoats & Wedding Wear",
     "ur": "واسکٹ اور شادی کے ملبوسات",
     "subs": [
         {"id": "waistcoat", "en": "Waistcoats", "ur": "واسکٹ"},
         {"id": "prince-coat", "en": "Prince coats", "ur": "پرنس کوٹ"},
         {"id": "sherwani", "en": "Sherwanis", "ur": "شیروانی"},
         {"id": "achkan", "en": "Achkans", "ur": "اچکن"},
         {"id": "groom", "en": "Groom ensembles", "ur": "دولہا کے جوڑے"},
     ]},
    {"id": "m-bottoms", "audience": "men", "en": "Bottoms", "ur": "شلوار و پاجامہ",
     "subs": [
         {"id": "shalwar", "en": "Shalwars", "ur": "شلواریں"},
         {"id": "pajama", "en": "Pajamas", "ur": "پاجامے"},
         {"id": "churidar", "en": "Churidars", "ur": "چوڑی دار"},
         {"id": "trousers", "en": "Straight trousers", "ur": "سیدھی پتلون"},
     ]},
    {"id": "m-shawls", "audience": "men", "en": "Shawls & Stoles", "ur": "شالیں",
     "subs": [
         {"id": "everyday-shawl", "en": "Everyday shawls", "ur": "روزمرہ شالیں"},
         {"id": "winter-shawl", "en": "Winter shawls", "ur": "سردیوں کی شالیں"},
         {"id": "formal-stole", "en": "Formal stoles", "ur": "فارمل اسٹول"},
     ]},
    {"id": "m-jubbas", "audience": "men", "en": "Jubbas & Thobes",
     "ur": "جبے اور توب",
     "subs": [
         {"id": "plain", "en": "Plain", "ur": "سادہ"},
         {"id": "embroidered", "en": "Embroidered", "ur": "کڑھائی والے"},
     ]},
    {"id": "m-suits", "audience": "men", "en": "Suits & Blazers", "ur": "سوٹ اور بلیزر",
     "subs": [
         {"id": "two-piece-suit", "en": "Two-piece suits", "ur": "ٹو پیس سوٹ"},
         {"id": "three-piece-suit", "en": "Three-piece suits", "ur": "تھری پیس سوٹ"},
         {"id": "blazer", "en": "Blazers", "ur": "بلیزر"},
         {"id": "formal-shirt", "en": "Formal shirts", "ur": "فارمل شرٹس"},
     ]},
]

BUYING_OPTIONS = [
    {"id": "unstitched", "en": "Unstitched", "ur": "بغیر سلا"},
    {"id": "semi-stitched", "en": "Semi-stitched", "ur": "نیم سلا"},
    {"id": "ready-made", "en": "Ready-made", "ur": "تیار"},
    {"id": "custom-stitching", "en": "Custom stitching", "ur": "اپنی سلائی"},
]

OCCASIONS = [
    {"id": "daily", "en": "Daily", "ur": "روزمرہ"},
    {"id": "workwear", "en": "Workwear", "ur": "دفتری لباس"},
    {"id": "eid", "en": "Eid", "ur": "عید"},
    {"id": "dinner-party", "en": "Dinner / party", "ur": "ڈنر / پارٹی"},
    {"id": "mehndi-dholki", "en": "Mehndi / dholki", "ur": "مہندی / ڈھولکی"},
    {"id": "nikkah", "en": "Nikkah", "ur": "نکاح"},
    {"id": "barat", "en": "Barat", "ur": "بارات"},
    {"id": "walima", "en": "Walima", "ur": "ولیمہ"},
    {"id": "wedding-guest", "en": "Wedding guest", "ur": "شادی کے مہمان"},
    {"id": "bridal", "en": "Bridal", "ur": "دلہن"},
    {"id": "groom", "en": "Groom", "ur": "دولہا"},
]

SEASONS = [
    {"id": "summer", "en": "Summer", "ur": "گرمی"},
    {"id": "winter", "en": "Winter", "ur": "سردی"},
    {"id": "mid-season", "en": "Mid-season", "ur": "درمیانی موسم"},
    {"id": "all-season", "en": "All-season", "ur": "ہر موسم"},
]

DESIGN_TYPES = [
    {"id": "plain", "en": "Plain", "ur": "سادہ"},
    {"id": "printed", "en": "Printed", "ur": "پرنٹڈ"},
    {"id": "embroidered", "en": "Embroidered", "ur": "کڑھائی"},
    {"id": "embellished", "en": "Embellished", "ur": "آرائشی"},
]

AVAILABILITY = [
    {"id": "ready-to-dispatch", "en": "Ready to dispatch", "ur": "فوری روانگی"},
    {"id": "made-to-order", "en": "Made to order", "ur": "آرڈر پر تیار"},
    {"id": "made-to-measure", "en": "Made to measure", "ur": "ناپ کے مطابق"},
    {"id": "preorder", "en": "Preorder", "ur": "پیشگی آرڈر"},
]

# Shopping fabric groups: browse labels, NOT fiber composition. A product
# stores its label here and its disclosed composition separately.
FABRIC_GROUPS = [
    {"id": "women-summer", "en": "Women: summer & everyday",
     "labels": ["lawn", "cotton", "cambric", "voile", "seersucker",
                 "cotton_dobby", "jacquard", "viscose"]},
    {"id": "women-winter", "en": "Women: winter",
     "labels": ["khaddar", "karandi", "marina", "dhanak", "velvet", "linen"]},
    {"id": "women-festive", "en": "Women: festive & formal",
     "labels": ["chiffon", "organza", "georgette", "net_tissue", "silk",
                 "raw_silk", "satin", "jacquard", "jamawar", "velvet"]},
    {"id": "men-summer", "en": "Men: summer & everyday",
     "labels": ["cotton", "cotton_latha", "wash_and_wear", "linen"]},
    {"id": "men-winter", "en": "Men: winter",
     "labels": ["khaddar", "karandi", "cotton", "wool_suiting",
                 "wash_and_wear"]},
    {"id": "men-festive", "en": "Men: festive & formal",
     "labels": ["boski", "silk", "jacquard", "jamawar", "raw_silk",
                 "wool_suiting"]},
]

# ---- Brand directory (retail candidates; supply arrangements TBC) ----
BRANDS = [
    # Women: everyday fabrics and clothing
    {"id": "khaadi", "name": "Khaadi", "url": "https://pk.khaadi.com/",
     "placements": ["w-unstitched", "w-everyday-rtw"]},
    {"id": "gul-ahmed", "name": "Gul Ahmed / Ideas",
     "url": "https://www.gulahmedshop.com/",
     "placements": ["w-unstitched", "w-everyday-rtw", "m-unstitched"]},
    {"id": "sapphire", "name": "SAPPHIRE", "url": "https://pk.sapphireonline.pk/",
     "placements": ["w-unstitched", "w-everyday-rtw", "w-modest", "w-bottoms"]},
    {"id": "alkaram", "name": "Alkaram Studio",
     "url": "https://www.alkaramstudio.com/",
     "placements": ["w-unstitched", "w-everyday-rtw", "m-traditional"]},
    {"id": "nishat", "name": "Nishat Linen", "url": "https://nishatlinen.com/",
     "placements": ["w-unstitched", "w-everyday-rtw"]},
    {"id": "limelight", "name": "Limelight", "url": "https://www.limelight.pk/",
     "placements": ["w-everyday-rtw"]},
    {"id": "beechtree", "name": "Beechtree", "url": "https://beechtree.pk/",
     "placements": ["w-everyday-rtw"]},
    {"id": "kayseria", "name": "Kayseria", "url": "https://sefam.com/pages/kayseria",
     "placements": ["w-unstitched"]},
    # Women: contemporary
    {"id": "ethnc", "name": "ETHNC / Ethnic", "url": "https://pk.ethnc.com/",
     "placements": ["w-everyday-rtw", "w-luxury-pret"]},
    {"id": "generation", "name": "GENERATION", "url": "https://generation.com.pk/",
     "placements": ["w-everyday-rtw"]},
    # Women: designer unstitched and festive
    {"id": "mariab", "name": "MARIA.B.", "url": "https://www.mariab.pk/",
     "placements": ["w-unstitched", "w-luxury-pret"]},
    {"id": "sana-safinaz", "name": "Sana Safinaz", "url": "https://sanasafinaz.com/",
     "placements": ["w-unstitched", "w-luxury-pret"]},
    {"id": "asim-jofa", "name": "Asim Jofa", "url": "https://asimjofa.com/",
     "placements": ["w-unstitched", "w-bridal"]},
    {"id": "bareeze", "name": "Bareeze", "url": "https://www.bareeze.com/",
     "placements": ["w-unstitched"]},
    {"id": "qalamkar", "name": "Qalamkar", "url": "https://www.qalamkar.com.pk/",
     "placements": ["w-unstitched", "w-bridal"]},
    {"id": "charizma", "name": "Charizma", "url": "https://houseofcharizma.com/",
     "placements": ["w-unstitched"]},
    {"id": "mushq", "name": "Mushq", "url": "https://us.mushq.com/",
     "placements": ["w-unstitched", "w-luxury-pret"]},
    # Women: luxury pret, formals, bridal
    {"id": "elan", "name": "Élan", "url": "https://elan.pk/",
     "placements": ["w-luxury-pret", "w-bridal"]},
    {"id": "faiza-saqlain", "name": "Faiza Saqlain",
     "url": "https://www.faizasaqlain.pk/",
     "placements": ["w-bridal"], "made_to_measure": True},
    {"id": "ammara-khan", "name": "Ammara Khan", "url": "https://www.ammarakhan.com/",
     "placements": ["w-luxury-pret", "w-bridal", "w-jackets-kotis"]},
    {"id": "shamaeel", "name": "Shamaeel Ansari", "url": "https://shamaeelansari.com/",
     "placements": ["w-luxury-pret"]},
    # Men: fabric specialists
    {"id": "pasha", "name": "Pasha Fabrics", "url": "https://www.pashafabrics.com/",
     "placements": ["m-unstitched"]},
    {"id": "grace", "name": "Grace Fabrics", "url": "https://gracefabrics.com/",
     "placements": ["m-unstitched"]},
    {"id": "dynasty", "name": "Dynasty Fabrics", "url": "https://www.dynastyfabrics.com/",
     "placements": ["m-unstitched", "m-traditional"]},
    # Men: everyday traditional and unstitched
    {"id": "junaid-jamshed", "name": "J. — Junaid Jamshed",
     "url": "https://www.junaidjamshed.com/",
     "placements": ["m-traditional", "m-unstitched", "m-wedding", "m-bottoms",
                     "m-jubbas"]},
    {"id": "edenrobe", "name": "edenrobe", "url": "https://edenrobe.com/",
     "placements": ["m-traditional", "m-kurtas"]},
    {"id": "bonanza", "name": "Bonanza Satrangi", "url": "https://bonanzasatrangi.com/",
     "placements": ["m-traditional"]},
    # Men: wedding and occasionwear
    {"id": "amir-adnan", "name": "Amir Adnan", "url": "https://amiradnan.com/",
     "placements": ["m-wedding"]},
    {"id": "republic", "name": "Republic by Omar Farooq",
     "url": "https://republicbyomarfarooq.com/",
     "placements": ["m-wedding", "m-suits"]},
    {"id": "humayun-alamgir", "name": "Humayun Alamgir",
     "url": "https://humayunalamgir.com/",
     "placements": ["m-wedding"]},
]

# Sourcing contacts that are NOT verified consumer storefronts (mills,
# processors) — the sourcing agent's beat, never shown as shop brands.
SUPPLIERS = [
    {"id": "ahmad-jamal", "name": "Ahmad Jamal Textile Mills",
     "url": "https://ahmadjamal.pk/",
     "note": "Dyeing/printing/finishing mill — potential fabric source, "
             "pending retail verification."},
]


def full_taxonomy() -> dict:
    """The whole tree, served at /taxonomy for clients to render filters."""
    return {
        "audiences": AUDIENCES,
        "categories": CATEGORIES,
        "buying_options": BUYING_OPTIONS,
        "occasions": OCCASIONS,
        "seasons": SEASONS,
        "design_types": DESIGN_TYPES,
        "availability": AVAILABILITY,
        "fabric_groups": FABRIC_GROUPS,
        "brands": BRANDS,
    }
