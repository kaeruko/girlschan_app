# -*- coding: utf-8 -*-
"""
ガールズちゃんねる（Girls Channel）の各セクションをまとめてスクレイピングするスクリプト
対応:
  - 新着トピック
  - 一週間の人気トピック
  - 前日の人気トピック
  - カテゴリ一覧
  - 人気キーワード一覧
"""

import os
import csv
import requests
from bs4 import BeautifulSoup

# ======= 設定 =======
USE_LOCAL_HTML = True  # Trueならローカルファイル、Falseならウェブから取得
LOCAL_HTML_PATH = "新着トピック _ ガールズちゃんねる - Girls Channel -.txt"
URL = "https://girlschannel.net/new/"

# ======= HTMLロード =======
if USE_LOCAL_HTML:
    with open(LOCAL_HTML_PATH, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")
else:
    html = requests.get(URL).text
    soup = BeautifulSoup(html, "html.parser")

# ------------------------------------------------------------
# 🧩 新着トピック
# ------------------------------------------------------------
new_topics = []
for li in soup.select("ul.topic-list > li"):
    a = li.find("a", href=True)
    if not a:
        continue
    title = a.select_one("p.title").get_text(strip=True)
    href = a["href"]
    comment = None
    time_text = None
    info = a.select_one("div.info p.comment")
    if info:
        spans = [t.get_text(strip=True) for t in info.find_all("span")]
        for s in spans:
            if "コメント" in s:
                comment = s.replace("コメント", "")
            elif any(x in s for x in ["秒", "分", "時間", "日前"]):
                time_text = s
    new_topics.append({
        "title": title,
        "url": href,
        "comments": comment,
        "time": time_text,
    })

# ------------------------------------------------------------
# 🌟 一週間の人気トピック
# ------------------------------------------------------------
weekly = []
for li in soup.select("div.sub-topics ul li a"):
    title = li.select_one(".title")
    comment = li.select_one(".comment")
    if title and comment:
        weekly.append({
            "title": title.get_text(strip=True),
            "url": li["href"],
            "comments": comment.get_text(strip=True),
        })

# ------------------------------------------------------------
# 🌙 前日の人気トピック
# ------------------------------------------------------------
yesterday = []
for li in soup.select("div.sub-topics-yesterday ul li a"):
    title = li.select_one(".title")
    comment = li.select_one(".comment")
    if title and comment:
        yesterday.append({
            "title": title.get_text(strip=True),
            "url": li["href"],
            "comments": comment.get_text(strip=True),
        })

# ------------------------------------------------------------
# 🏷 カテゴリ一覧
# ------------------------------------------------------------
categories = [
    li.get_text(strip=True)
    for li in soup.select("ul.category li, div.sub-categories ul li")
]

# ------------------------------------------------------------
# 🔖 人気キーワード一覧
# ------------------------------------------------------------
keywords = [
    a.get_text(strip=True).replace("# ", "")
    for a in soup.select("ul.keywords li a")
]

# ------------------------------------------------------------
# 💾 保存
# ------------------------------------------------------------
os.makedirs("output", exist_ok=True)

# 新着トピック
with open("output/girlschannel_new.csv", "w", newline="", encoding="utf-8-sig") as f:
    writer = csv.DictWriter(f, fieldnames=["title", "url", "comments", "time"])
    writer.writeheader()
    writer.writerows(new_topics)

# 人気（週・前日）
with open("output/girlschannel_popular_week.csv", "w", newline="", encoding="utf-8-sig") as f:
    writer = csv.DictWriter(f, fieldnames=["title", "url", "comments"])
    writer.writeheader()
    writer.writerows(weekly)

with open("output/girlschannel_popular_yesterday.csv", "w", newline="", encoding="utf-8-sig") as f:
    writer = csv.DictWriter(f, fieldnames=["title", "url", "comments"])
    writer.writeheader()
    writer.writerows(yesterday)

# カテゴリ・キーワード
with open("output/girlschannel_categories.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(categories))

with open("output/girlschannel_keywords.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(keywords))

# ------------------------------------------------------------
# ✅ 結果確認
# ------------------------------------------------------------
print(f"🆕 新着トピック: {len(new_topics)}件")
print(f"🌟 一週間人気: {len(weekly)}件")
print(f"🌙 前日人気: {len(yesterday)}件")
print(f"🏷 カテゴリ: {len(categories)}件")
print(f"🔖 キーワード: {len(keywords)}件")
print("\nCSV・TXT出力 → ./output/")
