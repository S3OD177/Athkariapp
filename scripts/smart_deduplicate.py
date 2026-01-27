import json
import os

def smart_deduplicate():
    res_path = "/Users/saud/xcodeproject/Athkariapp/Athkariapp/Resources"
    daily_path = os.path.join(res_path, "daily_athkar.json")
    
    with open(daily_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    athkar = data['athkar']
    
    # Essential adhkar that SHOULD be duplicated in both morning and evening
    # These are the most important and commonly recited
    essential_keywords = [
        'آية الكرسي',  # Ayat al-Kursi
        'قُلْ هُوَ اللَّهُ أَحَدٌ',  # Al-Ikhlas
        'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',  # Al-Falaq
        'قُلْ أَعُوذُ بِرَبِّ النَّاسِ',  # An-Nas
        'سيد الاستغفار',  # Sayyid al-Istighfar
        'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ',  # Morning/Evening dua
        'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ',
    ]
    
    def is_essential(item):
        """Check if this dhikr is essential and should be kept duplicated"""
        title = item.get('title', '')
        text = item.get('text', '')
        
        for keyword in essential_keywords:
            if keyword in title or keyword in text:
                return True
        return False
    
    # Group by text to find duplicates
    text_groups = {}
    for item in athkar:
        text_key = item['text'][:100]  # Use first 100 chars as key
        if text_key not in text_groups:
            text_groups[text_key] = []
        text_groups[text_key].append(item)
    
    # Process duplicates
    deduplicated = []
    processed_texts = set()
    
    for text_key, items in text_groups.items():
        if len(items) == 1:
            # No duplicate, keep it
            deduplicated.append(items[0])
        else:
            # Duplicate found
            if is_essential(items[0]):
                # Keep all duplicates for essential adhkar
                print(f"✓ Keeping duplicate: {items[0]['title'][:50]} (Essential)")
                deduplicated.extend(items)
            else:
                # Remove duplicates, keep only one (prefer morning)
                morning_item = next((i for i in items if i['category'] == 'morning'), None)
                if morning_item:
                    deduplicated.append(morning_item)
                    print(f"✗ Removed duplicate: {items[0]['title'][:50]} (Kept in morning)")
                else:
                    # If no morning, keep the first one
                    deduplicated.append(items[0])
                    print(f"✗ Removed duplicate: {items[0]['title'][:50]} (Kept first)")
    
    # Sort by category and orderIndex
    deduplicated.sort(key=lambda x: (x['category'], x['orderIndex']))
    
    # Save
    data['athkar'] = deduplicated
    with open(daily_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"\n✅ Deduplication complete!")
    print(f"   Original: {len(athkar)} items")
    print(f"   After deduplication: {len(deduplicated)} items")
    print(f"   Removed: {len(athkar) - len(deduplicated)} duplicates")

if __name__ == "__main__":
    smart_deduplicate()
