import json
import os

def generate_revision_html():
    res_path = "/Users/saud/xcodeproject/Athkariapp/Athkariapp/Resources"
    daily_path = os.path.join(res_path, "daily_athkar.json")
    hisn_path = os.path.join(res_path, "hisn.json")
    
    with open(daily_path, 'r', encoding='utf-8') as f:
        daily_data = json.load(f).get('athkar', [])
    with open(hisn_path, 'r', encoding='utf-8') as f:
        hisn_data = json.load(f)
        
    hisn_duas = hisn_data.get('duas', [])
    hisn_cats = {c['id']: c['name'] for c in hisn_data.get('categories', [])}
    
    daily_cat_names = {
        "morning": "أذكار الصباح",
        "evening": "أذكار المساء",
        "after_prayer": "أذكار بعد الصلاة",
        "sleep": "أذكار النوم",
        "waking": "الاستيقاظ من النوم"
    }

    html = """
    <!DOCTYPE html>
    <html lang="ar" dir="rtl">
    <head>
        <meta charset="UTF-8">
        <title>قائمة الأذكار الرسمية الشاملة | أذكاري</title>
        <link href="https://fonts.googleapis.com/css2?family=Amiri:wght@400;700&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
        <style>
            :root { --primary: #2563eb; --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --border: #334155; }
            body { font-family: 'Inter', sans-serif; background: var(--bg); color: var(--text); padding: 40px; }
            .container { max-width: 1300px; margin: 0 auto; }
            h1 { text-align: center; font-size: 2.5rem; margin-bottom: 10px; }
            .subtitle { text-align: center; color: #94a3b8; margin-bottom: 40px; }
            table { width: 100%; border-collapse: separate; border-spacing: 0; background: var(--card); border-radius: 12px; overflow: hidden; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); }
            th, td { padding: 18px; text-align: right; border-bottom: 1px solid var(--border); }
            th { background: #1e293b; font-weight: 600; font-size: 0.9rem; color: #94a3b8; text-transform: uppercase; }
            .cat-tag { color: var(--primary); font-weight: 700; white-space: nowrap; }
            .title { font-weight: 600; width: 180px; }
            .text { font-family: 'Amiri', serif; font-size: 1.35rem; line-height: 1.8; color: #fff; min-width: 450px; }
            .ref { font-size: 0.85rem; color: #94a3b8; width: 220px; }
            .rep { background: rgba(37, 99, 235, 0.15); color: var(--primary); padding: 4px 10px; border-radius: 6px; font-weight: 700; }
            tr:hover { background: rgba(255, 255, 255, 0.03); }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>قائمة الأذكار الشاملة</h1>
            <div class="subtitle">تم المزامنة مع بيانات حصن المسلم الرسمية</div>
            <table>
                <thead>
                    <tr>
                        <th>القسم</th>
                        <th>العنوان</th>
                        <th>النص</th>
                        <th>التكرار</th>
                        <th>المرجع</th>
                    </tr>
                </thead>
                <tbody>
    """

    # Add Daily
    for item in daily_data:
        cat_name = daily_cat_names.get(item['category'], item['category'])
        html += f"""
        <tr>
            <td class="cat-tag">{cat_name}</td>
            <td class="title">{item['title']}</td>
            <td class="text">{item['text']}</td>
            <td><span class="rep">{item['repeat']['max']}</span></td>
            <td class="ref">{item.get('reference', '')}</td>
        </tr>
        """
    
    # Add Hisn
    for item in hisn_duas:
        cat_name = hisn_cats.get(item['category'], item['category'])
        html += f"""
        <tr>
            <td class="cat-tag">{cat_name}</td>
            <td class="title">{item['title']}</td>
            <td class="text">{item['text']}</td>
            <td><span class="rep">{item['repeat']['max']}</span></td>
            <td class="ref">{item.get('reference', '')}</td>
        </tr>
        """

    html += """
                </tbody>
            </table>
        </div>
    </body>
    </html>
    """
    
    output = "/Users/saud/xcodeproject/Athkariapp/adhkar_revision.html"
    with open(output, 'w', encoding='utf-8') as f:
        f.write(html)
    print(f"Generated: {output}")

if __name__ == "__main__":
    generate_revision_html()
