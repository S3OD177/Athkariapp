#!/usr/bin/env python3
"""
Convert Adhkar-json-main/adhkar.json into a unified adhkar.json for the app.

Output format matches the app's DhikrJSON structure with source/hisnCategory fields added.
"""

import json
import os
import sys

# Category mapping: source_id -> (source, category, hisnCategory)
# source: "daily" or "hisn"
# category: DhikrCategory rawValue for daily, "hisn" for hisn items
# hisnCategory: HisnCategory rawValue for hisn items, None for daily

CATEGORY_MAP = {
    # Daily athkar
    1: ("daily", None, None),         # أذكار الصباح والمساء - special split handling
    2: ("daily", "sleep", None),      # أذكار النوم
    27: ("daily", "after_prayer", None),  # الأذكار بعد السلام من الصلاة

    # Hisn categories
    3: ("hisn", "hisn", "waking"),    # أذكار الاستيقاظ من النوم
    4: ("hisn", "hisn", "home"),      # دعاء دخول الخلاء
    5: ("hisn", "hisn", "home"),      # دعاء الخروج من الخلاء
    6: ("hisn", "hisn", "wudu"),      # الذكر قبل الوضوء
    7: ("hisn", "hisn", "wudu"),      # الذكر بعد الفراغ من الوضوء
    8: ("hisn", "hisn", "home"),      # الذكر عند الخروج من المنزل
    9: ("hisn", "hisn", "home"),      # الذكر عند دخول المنزل
    10: ("hisn", "hisn", "prayer"),   # دعاء الذهاب إلى المسجد
    11: ("hisn", "hisn", "prayer"),   # دعاء دخول المسجد
    12: ("hisn", "hisn", "prayer"),   # دعاء الخروج من المسجد
    13: ("hisn", "hisn", "adhan"),    # أذكار الآذان
    14: ("hisn", "hisn", "misc"),     # دعاء ُلبْس الثوب
    15: ("hisn", "hisn", "misc"),     # دعاء ُلبْس الثوب الجديد
    16: ("hisn", "hisn", "misc"),     # الدعاء لمن لبس ثوبا جديدا
    17: ("hisn", "hisn", "misc"),     # ما يقول إذا وضع ثوبه
    18: ("hisn", "hisn", "prayer"),   # دعاء الاستفتاح
    19: ("hisn", "hisn", "prayer"),   # دعاء الركوع
    20: ("hisn", "hisn", "prayer"),   # دعاء الرفع من الركوع
    21: ("hisn", "hisn", "prayer"),   # دعاء السجود
    22: ("hisn", "hisn", "prayer"),   # دعاء الجلسة بين السجدتين
    23: ("hisn", "hisn", "prayer"),   # دعاء سجود التلاوة
    24: ("hisn", "hisn", "prayer"),   # التشهد
    25: ("hisn", "hisn", "prayer"),   # الصلاة على النبي بعد التشهد
    26: ("hisn", "hisn", "prayer"),   # الدعاء بعد التشهد الأخير قبل السلام
    28: ("hisn", "hisn", "prayer"),   # دعاء صلاة الاستخارة
    29: ("hisn", "hisn", "sleeping"), # الدعاء إذا تقلب ليلا
    30: ("hisn", "hisn", "sleeping"), # دعاء الفزع في النوم
    31: ("hisn", "hisn", "sleeping"), # ما يفعل من رأى الرؤيا أو الحلم
    32: ("hisn", "hisn", "prayer"),   # دعاء قنوت الوتر
    33: ("hisn", "hisn", "prayer"),   # الذكر عقب السلام من الوتر
    34: ("hisn", "hisn", "distress"), # دعاء الهم والحزن
    35: ("hisn", "hisn", "distress"), # دعاء الكرب
    36: ("hisn", "hisn", "protection"),  # دعاء لقاء العدو و ذي السلطان
    37: ("hisn", "hisn", "protection"),  # دعاء من خاف ظلم السلطان
    38: ("hisn", "hisn", "protection"),  # الدعاء على العدو
    39: ("hisn", "hisn", "protection"),  # ما يقول من خاف قوما
    40: ("hisn", "hisn", "protection"),  # دعاء من أصابه وسوسة في الإيمان
    41: ("hisn", "hisn", "distress"),    # دعاء قضاء الدين
    42: ("hisn", "hisn", "prayer"),      # دعاء الوسوسة في الصلاة و القراءة
    43: ("hisn", "hisn", "distress"),    # دعاء من استصعب عليه أمر
    44: ("hisn", "hisn", "forgiveness"), # ما يقول ويفعل من أذنب ذنبا
    45: ("hisn", "hisn", "protection"),  # دعاء طرد الشيطان و وساوسه
    46: ("hisn", "hisn", "misc"),        # الدعاء حينما يقع ما لا يرضاه
    47: ("hisn", "hisn", "misc"),        # تهنئة المولود
    48: ("hisn", "hisn", "protection"),  # ما يعوذ به الأولاد
    49: ("hisn", "hisn", "illness"),     # الدعاء للمريض في عيادته
    50: ("hisn", "hisn", "illness"),     # فضل عيادة المريض
    51: ("hisn", "hisn", "illness"),     # دعاء المريض الذي يئس من حياته
    52: ("hisn", "hisn", "illness"),     # تلقين المحتضر
    53: ("hisn", "hisn", "illness"),     # دعاء من أصيب بمصيبة
    54: ("hisn", "hisn", "illness"),     # الدعاء عند إغماض الميت
    55: ("hisn", "hisn", "illness"),     # الدعاء للميت في الصلاة عليه
    56: ("hisn", "hisn", "illness"),     # الدعاء للفرط في الصلاة عليه
    57: ("hisn", "hisn", "illness"),     # دعاء التعزية
    58: ("hisn", "hisn", "illness"),     # الدعاء عند إدخال الميت القبر
    59: ("hisn", "hisn", "illness"),     # الدعاء بعد دفن الميت
    60: ("hisn", "hisn", "illness"),     # دعاء زيارة القبور
    61: ("hisn", "hisn", "misc"),        # دعاء الريح
    62: ("hisn", "hisn", "misc"),        # دعاء الرعد
    63: ("hisn", "hisn", "misc"),        # من أدعية الاستسقاء
    64: ("hisn", "hisn", "misc"),        # الدعاء إذا نزل المطر
    65: ("hisn", "hisn", "misc"),        # الذكر بعد نزول المطر
    66: ("hisn", "hisn", "misc"),        # من أدعية الاستصحاء
    67: ("hisn", "hisn", "misc"),        # دعاء رؤية الهلال
    68: ("hisn", "hisn", "food"),        # الدعاء عند إفطار الصائم
    69: ("hisn", "hisn", "food"),        # الدعاء قبل الطعام
    70: ("hisn", "hisn", "food"),        # الدعاء عند الفراغ من الطعام
    71: ("hisn", "hisn", "food"),        # دعاء الضيف لصاحب الطعام
    72: ("hisn", "hisn", "food"),        # التعريض بالدعاء لطلب الطعام أو الشراب
    73: ("hisn", "hisn", "food"),        # الدعاء إذا أفطر عند أهل بيت
    74: ("hisn", "hisn", "food"),        # دعاء الصائم إذا حضر الطعام ولم يفطر
    75: ("hisn", "hisn", "food"),        # ما يقول الصائم إذا سابه أحد
    76: ("hisn", "hisn", "food"),        # الدعاء عند رؤية باكورة الثمر
    77: ("hisn", "hisn", "misc"),        # دعاء العطاس
    78: ("hisn", "hisn", "misc"),        # ما يقال للكافر إذا عطس
    79: ("hisn", "hisn", "misc"),        # الدعاء للمتزوج
    80: ("hisn", "hisn", "misc"),        # دعاء المتزوج و شراء الدابة
    81: ("hisn", "hisn", "misc"),        # الدعاء قبل إتيان الزوجة
    82: ("hisn", "hisn", "protection"),  # دعاء الغضب
    83: ("hisn", "hisn", "misc"),        # دعاء من رأى مبتلى
    84: ("hisn", "hisn", "misc"),        # ما يقال في المجلس
    85: ("hisn", "hisn", "misc"),        # كفارة المجلس
    86: ("hisn", "hisn", "misc"),        # الدعاء لمن قال غفر الله لك
    87: ("hisn", "hisn", "gratitude"),   # الدعاء لمن صنع إليك معروفا
    88: ("hisn", "hisn", "protection"),  # ما يعصم الله به من الدجال
    89: ("hisn", "hisn", "misc"),        # الدعاء لمن قال إني أحبك في الله
    90: ("hisn", "hisn", "misc"),        # الدعاء لمن عرض عليك ماله
    91: ("hisn", "hisn", "misc"),        # الدعاء لمن أقرض عند القضاء
    92: ("hisn", "hisn", "protection"),  # دعاء الخوف من الشرك
    93: ("hisn", "hisn", "misc"),        # الدعاء لمن قال بارك الله فيك
    94: ("hisn", "hisn", "protection"),  # دعاء كراهية الطيرة
    95: ("hisn", "hisn", "travel"),      # دعاء الركوب
    96: ("hisn", "hisn", "travel"),      # دعاء السفر
    97: ("hisn", "hisn", "travel"),      # دعاء دخول القرية أو البلدة
    98: ("hisn", "hisn", "travel"),      # دعاء دخول السوق
    99: ("hisn", "hisn", "travel"),      # الدعاء إذا تعس المركوب
    100: ("hisn", "hisn", "travel"),     # دعاء المسافر للمقيم
    101: ("hisn", "hisn", "travel"),     # دعاء المقيم للمسافر
    102: ("hisn", "hisn", "travel"),     # التكبير و التسبيح في سير السفر
    103: ("hisn", "hisn", "travel"),     # دعاء المسافر إذا أسحر
    104: ("hisn", "hisn", "travel"),     # الدعاء إذا نزل منزلا في سفر أو غيره
    105: ("hisn", "hisn", "travel"),     # ذكر الرجوع من السفر
    106: ("hisn", "hisn", "misc"),       # ما يقول من أتاه أمر يسره أو يكرهه
    107: ("hisn", "hisn", "prayer"),     # فضل الصلاة على النبي
    108: ("hisn", "hisn", "misc"),       # إفشاء السلام
    109: ("hisn", "hisn", "misc"),       # كيف يرد السلام على الكافر
    110: ("hisn", "hisn", "misc"),       # الدُّعاءُ عِنْدَ سَمَاعِ صِياحِ الدِّيكِ
    111: ("hisn", "hisn", "misc"),       # دعاء نباح الكلاب بالليل
    112: ("hisn", "hisn", "forgiveness"),# الدعاء لمن سببته
    113: ("hisn", "hisn", "misc"),       # ما يقول المسلم إذا مدح المسلم
    114: ("hisn", "hisn", "misc"),       # ما يقول المسلم إذا زكي
    115: ("hisn", "hisn", "misc"),       # كيف يلبي المحرم
    116: ("hisn", "hisn", "misc"),       # التكبير إذا أتى الركن الأسود
    117: ("hisn", "hisn", "misc"),       # الدعاء بين الركن اليماني والحجر الأسود
    118: ("hisn", "hisn", "misc"),       # دعاء الوقوف على الصفا والمروة
    119: ("hisn", "hisn", "misc"),       # الدعاء يوم عرفة
    120: ("hisn", "hisn", "misc"),       # الذكر عند المشعر الحرام
    121: ("hisn", "hisn", "misc"),       # التكبير عند رمي الجمار
    122: ("hisn", "hisn", "gratitude"),  # دعاء التعجب والأمر السار
    123: ("hisn", "hisn", "gratitude"),  # ما يفعل من أتاه أمر يسره
    124: ("hisn", "hisn", "illness"),    # ما يقول من أحس وجعا في جسده
    125: ("hisn", "hisn", "protection"), # دعاء من خشي أن يصيب شيئا بعينه
    126: ("hisn", "hisn", "protection"), # ما يقال عند الفزع
    127: ("hisn", "hisn", "misc"),       # ما يقول عند الذبح أو النحر
    128: ("hisn", "hisn", "protection"), # ما يقول لرد كيد مردة الشياطين
    129: ("hisn", "hisn", "forgiveness"),# الاستغفار و التوبة
    130: ("hisn", "hisn", "gratitude"),  # فضل التسبيح و التحميد
    131: ("hisn", "hisn", "gratitude"),  # كيف كان النبي يسبح؟
    132: ("hisn", "hisn", "misc"),       # من أنواع الخير والآداب الجامعة
}

# Morning-specific keywords (text contains these → morning only)
MORNING_KEYWORDS = ["أَصْبَحْنَا", "أَصْبَحْتُ", "أَصْبَحَ", "إذا أصبحَ", "إذا أصبح"]
# Evening-specific keywords
EVENING_KEYWORDS = ["أَمْسَيْنَا", "أَمْسَيْتُ", "أَمْسَى", "إذا أمسى"]


def classify_morning_evening(text):
    """Determine if a dhikr from category 1 is morning, evening, or both."""
    has_morning = any(kw in text for kw in MORNING_KEYWORDS)
    has_evening = any(kw in text for kw in EVENING_KEYWORDS)

    if has_morning and not has_evening:
        return ["morning"]
    if has_evening and not has_morning:
        return ["evening"]
    # Both keywords present (has annotation like [وإذا أمسى...]) or neither → both
    return ["morning", "evening"]


def make_id(source_cat_id, item_index, suffix=None):
    """Generate a unique ID for a dhikr item."""
    base = f"adhkar-{source_cat_id}-{item_index:03d}"
    if suffix:
        base += f"-{suffix}"
    return base


def convert_item(source_cat_id, source_category_name, item, item_index, category, hisn_category, source):
    """Convert a source adhkar item to the app's DhikrJSON format."""
    return {
        "id": make_id(source_cat_id, item_index),
        "category": category,
        "hisnCategory": hisn_category,
        "source": source,
        "title": source_category_name,
        "text": item["text"],
        "reference": "",
        "repeat": {
            "min": item.get("count", 1),
            "max": item.get("count", 1),
            "note": None
        },
        "orderIndex": item_index + 1,
        "benefit": None,
        "grading": "sahih",
        "isOptional": False
    }


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)

    source_path = os.path.join(project_dir, "Adhkar-json-main", "adhkar.json")
    output_path = os.path.join(project_dir, "Athkariapp", "Resources", "adhkar.json")

    with open(source_path, "r", encoding="utf-8") as f:
        source_data = json.load(f)

    all_athkar = []
    stats = {"daily": 0, "hisn": 0, "total_source": 0}

    for cat in source_data:
        cat_id = cat["id"]
        cat_name = cat["category"]
        items = cat["array"]
        stats["total_source"] += len(items)

        if cat_id not in CATEGORY_MAP:
            print(f"WARNING: Unknown category id={cat_id} '{cat_name}' - skipping")
            continue

        mapping = CATEGORY_MAP[cat_id]

        # Special handling for category 1: morning/evening split
        if cat_id == 1:
            morning_index = 0
            evening_index = 0
            for item in items:
                classifications = classify_morning_evening(item["text"])
                for cls in classifications:
                    idx = morning_index if cls == "morning" else evening_index
                    entry = convert_item(
                        source_cat_id=cat_id,
                        source_category_name=f"أذكار الصباح" if cls == "morning" else "أذكار المساء",
                        item=item,
                        item_index=idx,
                        category=cls,
                        hisn_category=None,
                        source="daily"
                    )
                    # Make ID unique for morning/evening variants
                    entry["id"] = make_id(cat_id, item["id"] - 1, suffix=cls[0])
                    all_athkar.append(entry)
                    stats["daily"] += 1
                    if cls == "morning":
                        morning_index += 1
                    else:
                        evening_index += 1
            continue

        source_type, category, hisn_category = mapping

        for idx, item in enumerate(items):
            entry = convert_item(
                source_cat_id=cat_id,
                source_category_name=cat_name,
                item=item,
                item_index=idx,
                category=category,
                hisn_category=hisn_category,
                source=source_type
            )
            all_athkar.append(entry)
            stats[source_type] += 1

    # Build output
    output = {"athkar": all_athkar}

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Conversion complete!")
    print(f"  Source categories: {len(source_data)}")
    print(f"  Source items: {stats['total_source']}")
    print(f"  Output items: {len(all_athkar)}")
    print(f"    Daily: {stats['daily']}")
    print(f"    Hisn: {stats['hisn']}")
    print(f"  Output file: {output_path}")


if __name__ == "__main__":
    main()
