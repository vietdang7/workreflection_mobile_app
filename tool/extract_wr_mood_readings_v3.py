#!/usr/bin/env python3
"""
extract_wr_mood_readings_v3.py
==============================
Bóc BÀI ĐỌC của hai nhóm cảm xúc mới (`foggy`, `outofsync`) từ `CONTENT_LIBRARY`
trong mockup Sprint 2 v16, rồi ghép vào assets/seed/wr_mood_content.json.

  python3 tool/extract_wr_mood_readings_v3.py \
      --html ~/Desktop/FileTam/workreflection/WorkReflection_Sprint2_Mockup_v16.html

Nguồn: WorkReflection_Changelog_20260824.docx §3 (hai mood mới) và §4 (thư viện
nội dung đọc). File HTML nằm NGOÀI repo nên đường dẫn là tham số, cùng kiểu với
extract_wr_content.py và extract_wr_mood_readings.py.

QUY ƯỚC GHI ĐÈ (v3, 25/08/2026)
-------------------------------
* Bốn nhóm cũ (stress / tired / ok / happy) GIỮ NGUYÊN 5 bài đọc toàn văn đã
  biên tập từ WorkReflection_HealingLibrary_ToanVan_v2.md (placeholder=false).

  Đây là chỗ tài liệu 24/08 và hiện trạng app lệch nhau, và bản giữ lại là bản
  của app. Changelog §4 mô tả mockup đi từ "1/20 bài có nội dung đầy đủ" lên đủ
  30 bài nháp; app đã vượt qua mốc đó từ 04/08 với bản toàn văn ĐÃ BIÊN TẬP.
  Thay 20 bài đã duyệt bằng 20 bản nháp mới là đi lùi.

* 10 mục HEALING AUDIO bị XOÁ HẲN, đúng §4: "chuyển toàn bộ mục trước đây là
  HEALING AUDIO sang BÀI ĐỌC". Chúng không được chuyển thành bài đọc thứ 6-8 của
  nhóm: §4 chốt đúng 30 bài = 5 bài × 6 mood, và ba mục "âm thanh nền" thuần tuý
  (mưa, nhạc tập trung, nhạc ăn mừng) vốn không có nội dung để đọc.

* 10 bài của `foggy` và `outofsync` lấy nguyên văn từ mockup, placeholder=true —
  §4: "Toàn bộ 30 bài vẫn giữ cờ placeholder:true (hiện Nháp trên UI)... Nếu
  chốt xong nội dung, cần đổi cờ này thành false trước khi lên bản chính thức."

Chạy xong nhớ sinh lại SQL:
  python3 tool/gen_wr_mood_content_sql.py \
      --migration supabase/migrations/20260825000001_wr_mood_content_six_moods.sql \
      --mode upsert
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
JSON_DEFAULT = REPO_ROOT / "assets" / "seed" / "wr_mood_content.json"

# Thứ tự nhóm trong file JSON — khớp thứ tự sáu ô check-in ở Home.
MOOD_ORDER = ("stress", "tired", "foggy", "outofsync", "ok", "happy")

# Hai nhóm bóc từ mockup. Bốn nhóm còn lại đọc lại từ JSON hiện có.
NEW_MOODS = ("foggy", "outofsync")

RE_GROUP = re.compile(r"^\s*(" + "|".join(NEW_MOODS) + r"):\[\s*$")
RE_HEAD = re.compile(
    r"^\s*\{title:'(?P<title>(?:[^'\\]|\\.)*)',\s*"
    r"kind:'(?P<kind>[^']*)',\s*"
    r"duration:'(?P<duration>[^']*)',\s*"
    r"type:'(?P<type>[^']*)',\s*"
    r"placeholder:(?P<placeholder>true|false),\s*$"
)
RE_BODY = re.compile(r"^\s*body:'(?P<body>.*)'\},?\s*$")


def js_unescape(s: str) -> str:
    """Chuỗi JS một nháy -> chuỗi Python. Chỉ gặp \\n và \\' trong nguồn này."""
    return (
        s.replace("\\n", "\n")
        .replace("\\'", "'")
        .replace('\\"', '"')
        .replace("\\\\", "\\")
    )


def parse_html(path: Path) -> list[dict]:
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[dict] = []
    mood: str | None = None
    i = 0

    while i < len(lines):
        m = RE_GROUP.match(lines[i])
        if m:
            mood = m.group(1)
            i += 1
            continue

        if mood is not None:
            head = RE_HEAD.match(lines[i])
            if head:
                body_line = lines[i + 1] if i + 1 < len(lines) else ""
                body = RE_BODY.match(body_line)
                if body is None:
                    print(
                        f"[ERROR] {head.group('title')!r}: dòng body không đúng khuôn",
                        file=sys.stderr,
                    )
                    sys.exit(1)
                out.append({
                    "mood": mood,
                    "title": js_unescape(head.group("title")),
                    "kind": head.group("kind"),
                    "duration": head.group("duration"),
                    "type": head.group("type"),
                    "body": js_unescape(body.group("body")),
                    "script": None,
                    "placeholder": head.group("placeholder") == "true",
                })
                i += 2
                continue
            # Hết nhóm: dòng `],` đóng mảng.
            if lines[i].strip() in ("],", "]"):
                mood = None
        i += 1

    return out


def validate_new(rows: list[dict]) -> None:
    errors = []
    for mood in NEW_MOODS:
        group = [r for r in rows if r["mood"] == mood]
        if len(group) != 5:
            errors.append(f"{mood}: bóc được {len(group)} bài, phải đủ 5")
    for r in rows:
        if r["type"] != "reading" or r["kind"] != "BÀI ĐỌC":
            errors.append(f"{r['title']!r}: §4 không còn HEALING AUDIO")
        # Ngưỡng 140 chứ không phải 250 như bản v2: bài của hai nhóm mới là
        # loại 2-3 phút (khoảng 170-200 từ), ngắn hơn hẳn loạt 4 phút trong
        # HealingLibrary_ToanVan_v2. Ngưỡng ở đây chỉ để bắt lỗi BÓC HỤT thân
        # bài, không phải để áp một độ dài tối thiểu lên nội dung.
        words = len(r["body"].split())
        if words < 140:
            errors.append(f"{r['title']!r}: chỉ {words} từ, nghi bóc hụt thân bài")
        # Nguyên tắc brand: nội dung luôn kết bằng câu hỏi mở (§4).
        if not r["body"].rstrip().endswith("?"):
            errors.append(f"{r['title']!r}: không kết bằng câu hỏi mở")
    titles = [r["title"] for r in rows]
    dup = {t for t in titles if titles.count(t) > 1}
    if dup:
        errors.append(f"tiêu đề trùng: {sorted(dup)}")
    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--html", required=True, help="đường dẫn mockup v16")
    parser.add_argument("--json", default=str(JSON_DEFAULT))
    args = parser.parse_args()

    fresh = parse_html(Path(args.html))
    validate_new(fresh)

    json_path = Path(args.json)
    old = json.loads(json_path.read_text(encoding="utf-8"))

    dropped = [r for r in old if r["type"] != "reading"]
    kept = [r for r in old if r["type"] == "reading"]

    by_mood: dict[str, list[dict]] = {m: [] for m in MOOD_ORDER}
    for r in kept:
        by_mood[r["mood"]].append(r)
    for r in fresh:
        by_mood[r["mood"]].append(r)

    ordered: list[dict] = []
    for mood in MOOD_ORDER:
        group = by_mood[mood]
        if len(group) != 5:
            print(f"[ERROR] {mood}: {len(group)} bài đọc, phải đủ 5", file=sys.stderr)
            sys.exit(1)
        for idx, r in enumerate(group, start=1):
            ordered.append({
                "mood": mood,
                "sort_order": idx,
                "title": r["title"],
                "kind": r["kind"],
                "duration": r["duration"],
                "type": r["type"],
                "body": r["body"],
                "script": None,
                "placeholder": r["placeholder"],
            })

    json_path.write_text(
        json.dumps(ordered, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    drafts = sum(1 for r in ordered if r["placeholder"])
    print(f"[OK] {json_path}", file=sys.stderr)
    print(f"     bài đọc  : {len(ordered)} trên 6 nhóm cảm xúc", file=sys.stderr)
    print(f"     thêm mới : {len(fresh)} (foggy + outofsync)", file=sys.stderr)
    print(f"     đã xoá   : {len(dropped)} mục HEALING AUDIO", file=sys.stderr)
    print(f"     còn nháp : {drafts} (placeholder=true)", file=sys.stderr)


if __name__ == "__main__":
    main()
