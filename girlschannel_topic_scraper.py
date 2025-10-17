# -*- coding: utf-8 -*-
import requests
from bs4 import BeautifulSoup
import csv
import re

def scrape_topic(topic_id):
    """トピックIDを受けてタイトルとコメント一覧を取得"""
    url = f"https://girlschannel.net/topics/{topic_id}/"
    print(f"Fetching: {url}")
    html = requests.get(url).text
    soup = BeautifulSoup(html, "html.parser")

    # ===== トピック情報 =====
    title = soup.select_one("h1").get_text(strip=True)
    info = soup.select_one(".head-area p.comment")
    comment_count = None
    date = None
    if info:
        spans = info.find_all("span")
        if len(spans) >= 2:
            comment_count = spans[1].get_text(strip=True)
        if len(spans) >= 3:
            date = spans[2].get_text(strip=True)

    # ===== コメント一覧 =====
    comments = []
    for li in soup.select("li.comment-item"):
        # コメント番号
        num_match = re.search(r"id=\"comment(\d+)\"", str(li))
        num = num_match.group(1) if num_match else None

        # 投稿日時
        time_tag = li.select_one("p.info a")
        time_text = time_tag.get_text(strip=True) if time_tag else None

        # 本文
        body = li.select_one(".body")
        body_text = body.get_text("\n", strip=True) if body else None

        # 評価（+/-）
        plus = li.select_one(".icon-rate-wrap-plus .counter p")
        minus = li.select_one(".icon-rate-wrap-minus .counter p")
        plus_count = plus.get_text(strip=True).replace("+", "") if plus else "0"
        minus_count = minus.get_text(strip=True).replace("-", "") if minus else "0"

        comments.append({
            "id": num,
            "time": time_text,
            "text": body_text,
            "plus": plus_count,
            "minus": minus_count,
        })

    # ===== CSV出力 =====
    csv_name = f"topic_{topic_id}.csv"
    with open(csv_name, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "time", "text", "plus", "minus"])
        writer.writeheader()
        writer.writerows(comments)
    print(f"✅ {len(comments)}件のコメントを保存しました → {csv_name}")

    return {
        "title": title,
        "comment_count": comment_count,
        "date": date,
        "comments": comments,
    }

# ===== 実行例 =====
if __name__ == "__main__":
    data = scrape_topic(5887805)
    print(f"タイトル: {data['title']}")
    print(f"コメント数: {len(data['comments'])}")
    print("\n--- 最初の3件 ---")
    for c in data["comments"][:3]:
        print(f"{c['id']}: {c['text']}")
