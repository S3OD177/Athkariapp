import json
import os
import urllib.request
import time

def fetch_json(url):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8-sig'))
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return None

def clean_text(text):
    if not text: return ""
    # Remove markers and normalize whitespace
    return " ".join(text.replace('۝', '').split()).strip()

def run_sync():
    print("🚀 Starting Sync with HisnMuslim API...")
    
    # 1. Fetch Index
    index_url = "https://www.hisnmuslim.com/api/ar/husn_ar.json"
    index_data = fetch_json(index_url)
    if not index_data:
        print("❌ Failed to fetch index. Aborting.")
        return
        
    categories = list(index_data.values())[0] if isinstance(index_data, dict) else index_data
    
    # Mappings for Daily Athkar
    daily_mapping = {
        27: ["morning", "evening"], # Special case: split into two
        28: ["sleep"],
        1: ["waking"],
        25: ["after_prayer"]
    }
    
    final_daily = []
    final_hisn_duas = []
    final_hisn_categories = []
    
    processed_ids = set()
    
    for cat in categories:
        cid = int(cat['ID'])
        ctitle = cat['TITLE']
        curl = cat['TEXT']
        
        print(f"📦 Processing: {ctitle} (ID: {cid})...")
        time.sleep(0.5) # Be gentle
        
        content = fetch_json(curl)
        if not content: continue
        
        items = list(content.values())[0] if isinstance(content, dict) else content
        
        # Determine if this belongs to Daily or Hisn Library
        is_daily = cid in daily_mapping
        
        # Create Category for Hisn Library if not daily
        if not is_daily:
            cat_id = f"hisn-cat-{cid}"
            final_hisn_categories.append({
                "id": cat_id,
                "name": ctitle,
                "icon": "leaf.fill" # Default icon
            })
        
        for idx, item in enumerate(items):
            # Map item to our DhikrJSON structure
            dhikr_id = f"sync-{cid}-{idx:03d}"
            text = clean_text(item.get('ARABIC_TEXT', ''))
            
            # Extract repeat count
            try:
                rep_val = int(item.get('REPEAT', 1))
            except:
                rep_val = 1
                
            dhikr_obj = {
                "id": dhikr_id,
                "category": "", # To be filled
                "title": ctitle if len(items) == 1 else f"{ctitle} ({idx+1})",
                "text": text,
                "reference": item.get('REFERENCE', ''),
                "repeat": {
                    "min": rep_val,
                    "max": rep_val,
                    "note": None
                },
                "orderIndex": idx + 1,
                "benefit": None,
                "grading": "sahih",
                "isOptional": False
            }
            
            if is_daily:
                target_cats = daily_mapping[cid]
                if cid == 27:
                    # Logic to split morning and evening if possible
                    # But the API puts them together. In our app we prefer them separate.
                    # For now, we'll put them in BOTH or keep existing separation?
                    # The user wants to APPLY the API. We'll follow the API's grouping for sync.
                    # Actually, let's keep it simple: if it's 27, we'll tag it as morning/evening based on index or title if possible.
                    # Better: duplicate for both safely, or just preserve the 'morning' category for all.
                    # Let's map 27 to morning and evening as specific categories if we find keywords.
                    if "صباح" in text or "أصبح" in text:
                        dhikr_obj["category"] = "morning"
                        final_daily.append(dhikr_obj)
                    elif "مسا" in text or "أمس" in text:
                        dhikr_obj["category"] = "evening"
                        final_daily.append(dhikr_obj)
                    else:
                        # Append to both if ambiguous? No, usually they are shared.
                        d1 = dhikr_obj.copy()
                        d1["category"] = "morning"
                        d1["id"] = f"{dhikr_id}-m"
                        final_daily.append(d1)
                        d2 = dhikr_obj.copy()
                        d2["category"] = "evening"
                        d2["id"] = f"{dhikr_id}-e"
                        final_daily.append(d2)
                else:
                    dhikr_obj["category"] = target_cats[0]
                    final_daily.append(dhikr_obj)
            else:
                dhikr_obj["category"] = f"cat-{cid}"
                final_hisn_duas.append(dhikr_obj)

    # 3. Save to Files
    res_path = "/Users/saud/xcodeproject/Athkariapp/Athkariapp/Resources"
    
    with open(os.path.join(res_path, "daily_athkar.json"), 'w', encoding='utf-8') as f:
        json.dump({"athkar": final_daily}, f, ensure_ascii=False, indent=2)
        
    with open(os.path.join(res_path, "hisn.json"), 'w', encoding='utf-8') as f:
        json.dump({
            "categories": final_hisn_categories,
            "duas": final_hisn_duas
        }, f, ensure_ascii=False, indent=2)

    print("✅ Sync Complete! Updated daily_athkar.json and hisn.json")

if __name__ == "__main__":
    run_sync()
