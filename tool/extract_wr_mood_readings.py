#!/usr/bin/env python3
"""
extract_wr_mood_readings.py
===========================
Bóc 20 BÀI ĐỌC toàn văn từ WorkReflection_HealingLibrary_ToanVan_v2.md và ghi
đè phần reading của assets/seed/wr_mood_content.json.

  python3 tool/extract_wr_mood_readings.py \
      --md ~/Desktop/FileTam/workreflection/WorkReflection_HealingLibrary_ToanVan_v2.md

File .md nằm NGOÀI repo (thư mục tài liệu của khách), nên đường dẫn là tham số
chứ không hard-code. Cùng kiểu với extract_wr_content.py.

Quy ước ghi đè (v2, 04/08/2026):
  * 20 BÀI ĐỌC chiếm sort_order 1..5 của mỗi nhóm cảm xúc, đúng thứ tự trong
    tài liệu. Đây là phần chính, placeholder = false (đã biên tập xong).
  * 10 HEALING AUDIO cũ được GIỮ NGUYÊN nội dung nhưng dồn xuống sort_order 6+,
    vẫn placeholder = true. Tài liệu xếp chúng vào phụ lục "chưa thu âm"; xoá đi
    thì mất luôn kịch bản lồng tiếng đã viết và mất đường thử luồng audio.

Chạy xong nhớ sinh lại SQL:
  python3 tool/gen_wr_mood_content_sql.py \
      --migration supabase/migrations/20260804160000_wr_mood_content_readings_v2.sql \
      --mode upsert
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
JSON_DEFAULT = REPO_ROOT / "assets" / "seed" / "wr_mood_content.json"

# Tiêu đề nhóm trong tài liệu -> khoá mood của §8.1.
GROUP_TO_MOOD = {
    "Căng thẳng": "stress",
    "Mệt mỏi": "tired",
    "Ổn định": "ok",
    "Vui vẻ": "happy",
}

RE_GROUP = re.compile(r"^#\s+\*\*Nhóm:\s*(.+?)\*\*\s*$")
RE_TITLE = re.compile(r"^##\s+\*\*(.+?)\*\*\s*$")
RE_META = re.compile(r"^\s*\*\*(BÀI ĐỌC|HEALING AUDIO)\*\*\s+\*(.+?)\*\s*$")
RE_HEADING = re.compile(r"^#{1,6}\s")


def unescape(s: str) -> str:
    """Bỏ dấu \\ mà trình xuất Google Docs chèn trước ký tự đặc biệt."""
    return re.sub(r"\\([\\`*_{}\[\]()#+\-.!=])", r"\1", s)


def parse_md(path: Path) -> list[dict]:
    lines = path.read_text(encoding="utf-8").splitlines()
    readings: list[dict] = []
    mood: str | None = None
    i = 0

    while i < len(lines):
        line = lines[i]

        m = RE_GROUP.match(line)
        if m:
            group = m.group(1).strip()
            mood = GROUP_TO_MOOD.get(group)
            if mood is None:
                print(f"[ERROR] Nhóm lạ: {group!r}", file=sys.stderr)
                sys.exit(1)
            i += 1
            continue

        m = RE_TITLE.match(line)
        if m and mood is not None:
            title = unescape(m.group(1).strip())

            # Dòng meta: **BÀI ĐỌC**    *4 phút đọc*
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            meta = RE_META.match(lines[j]) if j < len(lines) else None
            if meta is None:
                print(f"[ERROR] {title!r}: không tìm thấy dòng nhãn/thời lượng",
                      file=sys.stderr)
                sys.exit(1)
            kind, duration = meta.group(1), unescape(meta.group(2).strip())

            # Thân bài: tới heading kế tiếp.
            body_lines: list[str] = []
            k = j + 1
            while k < len(lines) and not RE_HEADING.match(lines[k]):
                body_lines.append(lines[k])
                k += 1

            body = "\n".join(body_lines).strip()
            body = re.sub(r"\n{3,}", "\n\n", unescape(body))

            if kind != "BÀI ĐỌC":
                # Phụ lục HEALING AUDIO: bỏ qua, phần audio cập nhật sau.
                i = k
                continue
            if not body:
                print(f"[ERROR] {title!r}: thân bài rỗng", file=sys.stderr)
                sys.exit(1)

            readings.append({
                "mood": mood,
                "title": title,
                "kind": kind,
                "duration": duration,
                "type": "reading",
                "body": body,
                "script": None,
                # Tài liệu v2: phần chính "sẵn sàng phát hành ngay
                # (placeholder=false)".
                "placeholder": False,
            })
            i = k
            continue

        i += 1

    return readings


def validate(readings: list[dict]) -> None:
    errors = []
    for mood in GROUP_TO_MOOD.values():
        group = [r for r in readings if r["mood"] == mood]
        if len(group) != 5:
            errors.append(f"{mood}: bóc được {len(group)} bài đọc, phải đủ 5")
    titles = [r["title"] for r in readings]
    dup = {t for t in titles if titles.count(t) > 1}
    if dup:
        errors.append(f"tiêu đề trùng: {sorted(dup)}")
    for r in readings:
        # 3 phút = 350-450 từ, 4 phút = 450-550 từ (ghi chú đầu tài liệu).
        words = len(r["body"].split())
        if words < 250:
            errors.append(f"{r['title']!r}: chỉ {words} từ, nghi bóc hụt thân bài")
    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--md", required=True, help="đường dẫn file toàn văn v2")
    parser.add_argument("--json", default=str(JSON_DEFAULT))
    args = parser.parse_args()

    readings = parse_md(Path(args.md))
    validate(readings)

    json_path = Path(args.json)
    old = json.loads(json_path.read_text(encoding="utf-8"))
    audios = [r for r in old if r["type"] == "audio"]

    rows: list[dict] = []
    for mood in GROUP_TO_MOOD.values():
        group = [r for r in readings if r["mood"] == mood]
        for idx, r in enumerate(group, start=1):
            rows.append({**r, "sort_order": idx})
        # Phụ lục audio dồn xuống sau, giữ nguyên thứ tự tương đối cũ.
        tail = sorted(
            (a for a in audios if a["mood"] == mood),
            key=lambda a: a["sort_order"],
        )
        for idx, a in enumerate(tail, start=len(group) + 1):
            rows.append({**a, "sort_order": idx})

    ordered = [
        {
            "mood": r["mood"],
            "sort_order": r["sort_order"],
            "title": r["title"],
            "kind": r["kind"],
            "duration": r["duration"],
            "type": r["type"],
            "body": r["body"],
            "script": r.get("script"),
            "placeholder": r["placeholder"],
        }
        for r in rows
    ]

    json_path.write_text(
        json.dumps(ordered, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"[OK] {json_path}", file=sys.stderr)
    print(f"     bài đọc : {len(readings)} (placeholder=false)", file=sys.stderr)
    print(f"     audio   : {len(audios)} (placeholder=true, chờ thu âm)",
          file=sys.stderr)


if __name__ == "__main__":
    main()
