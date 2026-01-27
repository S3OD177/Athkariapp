import json
import os
import urllib.request
from difflib import SequenceMatcher

def fetch_json(url):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8-sig'))
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return None

def similar(a, b):
    return SequenceMatcher(None, a, b).ratio()

def clean_text(text):
    # Remove markers like ۝ and extra whitespace
    return " ".join(text.replace('۝', '').split()).strip()

def run_comparison():
    local_base = "/Users/saud/xcodeproject/Athkariapp/Athkariapp/Resources"
    daily_path = os.path.join(local_base, "daily_athkar.json")
    hisn_path = os.path.join(local_base, "hisn.json")
    
    with open(daily_path, 'r', encoding='utf-8') as f:
        daily_data = json.load(f).get('athkar', [])
    with open(hisn_path, 'r', encoding='utf-8') as f:
        hisn_data = json.load(f).get('duas', [])
    
    local_all = daily_data + hisn_data
    
    # Mapping Remote IDs to Local Categories for context
    # format: {remote_id: "local_display_name"}
    mappings = {
        27: "أذكار الصباح والمساء",
        28: "أذكار النوم",
        1: "أذكار الاستيقاظ من النوم",
        25: "الأذكار بعد السلام من الصلاة"
    }
    
    report_items = []
    
    for rid, rname in mappings.items():
        print(f"Comparing Category: {rname} (Remote ID: {rid})")
        remote_url = f"https://www.hisnmuslim.com/api/ar/{rid}.json"
        remote_content = fetch_json(remote_url)
        
        if not remote_content:
            continue
            
        # Remote format is usually list of dicts with 'ID', 'TITLE', 'ARABIC_TEXT', 'REPEAT', 'REFERENCE'
        # The key might be the language name in Arabic, let's just get the first list value
        remote_items = list(remote_content.values())[0] if isinstance(remote_content, dict) else remote_content
        
        for r_item in remote_items:
            r_text = clean_text(r_item.get('ARABIC_TEXT', ''))
            r_title = r_item.get('TITLE', '')
            found = False
            best_match = None
            best_ratio = 0
            
            for l_item in local_all:
                l_text = clean_text(l_item.get('text', ''))
                ratio = similar(r_text[:200], l_text[:200]) # Fast check on first part
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_match = l_item
                
                if ratio > 0.85: # Good enough match
                    found = True
                    # Check for repeat count mismatch
                    r_rep = int(r_item.get('REPEAT', 1)) if r_item.get('REPEAT') else 1
                    l_rep = l_item.get('repeat', {}).get('max', 1)
                    if r_rep != l_rep:
                        report_items.append({
                            "status": "Repeat Mismatch",
                            "category": rname,
                            "title": r_title,
                            "remote": f"Text: {r_text[:100]}... | Repeat: {r_rep}",
                            "local": f"Text: {l_text[:100]}... | Repeat: {l_rep}"
                        })
                    break
            
            if not found:
                if best_ratio > 0.5: # Potential mismatch/correction needed
                    report_items.append({
                        "status": "Potential Mismatch",
                        "category": rname,
                        "title": r_title,
                        "remote": f"{r_text[:200]}...",
                        "local": f"{clean_text(best_match.get('text', ''))[:200]}... (Ratio: {best_ratio:.2f})"
                    })
                else:
                    report_items.append({
                        "status": "Missing",
                        "category": rname,
                        "title": r_title,
                        "remote": f"{r_text[:200]}...",
                        "local": "Not found in app"
                    })

    # Generate HTML Report
    html = f"""
    <!DOCTYPE html>
    <html lang="ar" dir="rtl">
    <head>
        <meta charset="UTF-8">
        <title>تقرير مقارنة API | أذكاري</title>
        <style>
            body {{ font-family: sans-serif; background: #f8fafc; padding: 20px; }}
            .container {{ max-width: 1200px; margin: 0 auto; }}
            h1 {{ color: #1e293b; text-align: center; }}
            table {{ width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }}
            th, td {{ padding: 15px; border-bottom: 1px solid #e2e8f0; text-align: right; }}
            th {{ background: #f1f5f9; color: #475569; }}
            .status-Missing {{ color: #dc2626; font-weight: bold; }}
            .status-Mismatch {{ color: #d97706; font-weight: bold; }}
            .status-Repeat {{ color: #2563eb; font-weight: bold; }}
            .text-box {{ font-size: 0.9rem; line-height: 1.5; max-width: 400px; overflow: hidden; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>تقرير مقارنة البيانات مع API حصن المسلم</h1>
            <table>
                <thead>
                    <tr>
                        <th>الحالة</th>
                        <th>القسم</th>
                        <th>العنوان</th>
                        <th>البيانات الرسمية (API)</th>
                        <th>بيانات التطبيق الحالي</th>
                    </tr>
                </thead>
                <tbody>
    """
    
    for item in report_items:
        status_class = "status-" + item['status'].split()[0]
        html += f"""
                    <tr>
                        <td class="{status_class}">{item['status']}</td>
                        <td>{item['category']}</td>
                        <td>{item['title']}</td>
                        <td><div class="text-box">{item['remote']}</div></td>
                        <td><div class="text-box">{item['local']}</div></td>
                    </tr>
        """
        
    html += """
                </tbody>
            </table>
        </div>
    </body>
    </html>
    """
    
    report_path = "/Users/saud/xcodeproject/Athkariapp/api_comparison_report.html"
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(html)
    print(f"Report generated at: {report_path}")

if __name__ == "__main__":
    run_comparison()
