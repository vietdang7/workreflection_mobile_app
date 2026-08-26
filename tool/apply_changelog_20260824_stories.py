#!/usr/bin/env python3
"""
apply_changelog_20260824_stories.py
===================================
Áp hai mục §1.3 và §1.4 của WorkReflection_Changelog_20260824.docx lên
assets/seed/wr_stories.json.

  python3 tool/apply_changelog_20260824_stories.py
  python3 tool/apply_changelog_20260824_stories.py --check   # chỉ báo, không ghi

VÌ SAO LÀ MỘT TOOL RIÊNG, KHÔNG SỬA TAY FILE JSON
-------------------------------------------------
wr_stories.json sinh ra từ `tool/extract_wr_content.py` (bóc từ hai file .docx
của khách). Sửa tay vào JSON thì lần tới ai đó chạy lại extract là mất sạch, mà
mất trong im lặng. Đặt sửa đổi thành một bước áp-đè có thể chạy lại nhiều lần
(idempotent) thì thứ tự đúng luôn là: extract → apply → gen SQL.

§1.3 — ĐỔI NGÔI "tôi" → "bạn"
-----------------------------
Áp cho `reflection_question` và `self_reflection`. Mục tiêu của changelog: câu
hỏi đọc như app đang hỏi chuyện trực tiếp với người dùng, thay vì người dùng tự
độc thoại.

KHÔNG đụng tới:
  * `story_content` — changelog ghi rõ "Giữ nguyên ngôi tôi ở phần story, vì đây
    là giọng kể của người khác để tạo sự đồng cảm".
  * `aha_message` — cùng lý do, nó là câu trích trong ngoặc kép.
  * đại từ phản thân "mình" ("công việc của mình") — chính ví dụ Trước/Sau của
    changelog giữ nguyên cụm này. Chỉ đổi khi "mình" đứng làm CHỦ NGỮ thay cho
    "tôi".

Trong bộ 110 story hiện có, chỉ nhóm P-* (tình huống tích cực, soạn sau) còn
dùng ngôi "tôi"; toàn bộ S/C/A đã ở ngôi "bạn" từ trước.

§1.4 — SỬA 4 CẶP CÂU CHUYỆN / CÂU HỎI LỆCH LOGIC
------------------------------------------------
Câu chuyện thể hiện sự không chắc chắn, nhưng câu hỏi lại giả định sẵn một câu
trả lời tích cực, dứt khoát. Bốn câu thay thế lấy NGUYÊN VĂN từ changelog.
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
JSON_DEFAULT = REPO_ROOT / "assets" / "seed" / "wr_stories.json"

# ---------------------------------------------------------------------------
# §1.4 — bốn cặp lệch logic. (story_id, trường) -> (câu cũ, câu mới)
# ---------------------------------------------------------------------------

LOGIC_FIXES = {
    ("A3-04", "reflection_question"): (
        "Nếu phải kể một thay đổi tích cực của mình trong năm nay, "
        "bạn sẽ kể điều gì?",
        "Nếu cố nhớ lại, điều gì có thể là một thay đổi nhỏ mà bạn "
        "đã không để ý?",
    ),
    ("A1-03", "reflection_question"): (
        "Điều gì làm bạn cảm thấy công việc của mình đáng để tiếp tục?",
        "Nếu cố tìm, điều gì trong tuần này có thể là một phần ý nghĩa "
        "mà bạn chưa kịp nhận ra?",
    ),
    ("A1-06", "reflection_question"): (
        "Điều gì cho bạn thấy mình đang phát triển?",
        "Nếu cố tìm, điều gì có thể là một dấu hiệu nhỏ cho thấy bạn "
        "đang trưởng thành, dù chưa thật rõ ràng?",
    ),
    ("P-04", "reflection_question"): (
        "Điều gì trong hành trình vừa qua khiến tôi xứng đáng với điều này?",
        "Điều gì trong hành trình vừa qua đã dẫn bạn đến điều này?",
    ),
}

# ---------------------------------------------------------------------------
# §1.3 — đổi ngôi. (story_id, trường) -> (câu cũ, câu mới)
#
# Liệt kê từng câu chứ không thay chuỗi bằng regex "tôi" -> "bạn": tiếng Việt
# đổi ngôi kéo theo cả đại từ sở hữu và trật tự vế câu, và một phép thay máy móc
# sẽ đẻ ra "hay có phần nào trong bạn vẫn nghi ngờ" nhưng cũng đổi luôn cả
# những chỗ "mình" cần giữ. Liệt kê tay thì mỗi câu đều đọc qua một lần.
# ---------------------------------------------------------------------------

VOICE_FIXES = {
    ("P-01", "reflection_question"): (
        "Điều gì đã giúp tôi vượt qua được việc này?",
        "Điều gì đã giúp bạn vượt qua được việc này?",
    ),
    ("P-01", "self_reflection"): (
        "Tôi có thường dừng lại để ghi nhận những lúc mình làm tốt không?",
        "Bạn có thường dừng lại để ghi nhận những lúc mình làm tốt không?",
    ),
    ("P-02", "reflection_question"): (
        "Lời ghi nhận đó chạm vào điều gì ở tôi?",
        "Lời ghi nhận đó chạm vào điều gì ở bạn?",
    ),
    ("P-02", "self_reflection"): (
        "Tôi có tin vào điều đó, hay có phần nào trong tôi vẫn nghi ngờ?",
        "Bạn có tin vào điều đó, hay có phần nào trong bạn vẫn nghi ngờ?",
    ),
    ("P-03", "reflection_question"): (
        "Điều gì khiến tôi sẵn sàng dừng lại để giúp, "
        "dù có thể mình cũng đang bận?",
        "Điều gì khiến bạn sẵn sàng dừng lại để giúp, "
        "dù có thể mình cũng đang bận?",
    ),
    ("P-04", "self_reflection"): (
        "Tôi có đang cho phép mình thật sự vui với điều này không, "
        "hay đã vội nghĩ đến áp lực tiếp theo?",
        "Bạn có đang cho phép mình thật sự vui với điều này không, "
        "hay đã vội nghĩ đến áp lực tiếp theo?",
    ),
    ("P-05", "reflection_question"): (
        "Việc gì tôi làm mà tưởng là nhỏ, nhưng lại có ý nghĩa với người khác?",
        "Việc gì bạn làm mà tưởng là nhỏ, nhưng lại có ý nghĩa với người khác?",
    ),
    ("P-05", "self_reflection"): (
        "Tôi có hay đánh giá thấp những đóng góp thầm lặng của chính mình không?",
        "Bạn có hay đánh giá thấp những đóng góp thầm lặng của chính mình không?",
    ),
    ("P-06", "reflection_question"): (
        "Những ngày như thế này có thường xảy ra với tôi không?",
        "Những ngày như thế này có thường xảy ra với bạn không?",
    ),
    ("P-06", "self_reflection"): (
        "Tôi có coi trọng những ngày ổn định, hay chỉ chú ý khi có chuyện xảy ra?",
        "Bạn có coi trọng những ngày ổn định, hay chỉ chú ý khi có chuyện xảy ra?",
    ),
    ("P-07", "reflection_question"): (
        "Điều gì khác biệt hôm nay so với những ngày tôi cảm thấy bị cuốn đi?",
        "Điều gì khác biệt hôm nay so với những ngày bạn cảm thấy bị cuốn đi?",
    ),
    ("P-07", "self_reflection"): (
        "Tôi có thể giữ được nhịp độ này trong bao lâu?",
        "Bạn có thể giữ được nhịp độ này trong bao lâu?",
    ),
    ("P-08", "reflection_question"): (
        "Điều nhỏ này có thể thay đổi cách tôi làm việc về lâu dài không?",
        "Điều nhỏ này có thể thay đổi cách bạn làm việc về lâu dài không?",
    ),
    ("P-08", "self_reflection"): (
        "Tôi có thường bỏ qua những bài học nhỏ "
        "vì chúng không đủ lớn để ghi nhớ không?",
        "Bạn có thường bỏ qua những bài học nhỏ "
        "vì chúng không đủ lớn để ghi nhớ không?",
    ),
    ("P-09", "self_reflection"): (
        "Tôi có đang dành đủ thời gian cho những kết nối như vậy không?",
        "Bạn có đang dành đủ thời gian cho những kết nối như vậy không?",
    ),
    ("P-10", "reflection_question"): (
        "Tôi có công nhận những ngày không có gì đặc biệt này không, "
        "hay chỉ nhớ những ngày nhiều biến động?",
        "Bạn có công nhận những ngày không có gì đặc biệt này không, "
        "hay chỉ nhớ những ngày nhiều biến động?",
    ),
    ("P-10", "self_reflection"): (
        "Điều gì đang diễn ra tốt mà tôi ít khi để ý tới?",
        "Điều gì đang diễn ra tốt mà bạn ít khi để ý tới?",
    ),
}

ALL_FIXES = {**LOGIC_FIXES, **VOICE_FIXES}

# Hai trường DUY NHẤT được phép đổi ngôi.
QUESTION_FIELDS = ("reflection_question", "self_reflection")


def apply(rows: list[dict]) -> tuple[int, int, list[str]]:
    by_id = {r["story_id"]: r for r in rows}
    applied = already = 0
    problems: list[str] = []

    for (sid, field), (old, new) in ALL_FIXES.items():
        row = by_id.get(sid)
        if row is None:
            problems.append(f"{sid}: không có trong thư viện")
            continue
        current = row.get(field)
        if current == new:
            already += 1
        elif current == old:
            row[field] = new
            applied += 1
        else:
            problems.append(
                f"{sid}.{field}: nội dung không khớp cả bản cũ lẫn bản mới\n"
                f"    đang có : {current!r}\n"
                f"    chờ đợi : {old!r}"
            )
    return applied, already, problems


def audit_voice(rows: list[dict]) -> list[str]:
    """Còn câu hỏi nào dùng 'tôi' làm chủ ngữ thì báo — §1.3 không cho phép."""
    import re

    left = []
    pattern = re.compile(r"\bTôi\b|\btôi\b")
    for r in rows:
        for f in QUESTION_FIELDS:
            v = r.get(f) or ""
            if pattern.search(v):
                left.append(f"{r['story_id']}.{f}: {v}")
    return left


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", default=str(JSON_DEFAULT))
    parser.add_argument("--check", action="store_true",
                        help="chỉ kiểm tra, không ghi file")
    args = parser.parse_args()

    path = Path(args.json)
    rows = json.loads(path.read_text(encoding="utf-8"))

    applied, already, problems = apply(rows)

    for p in problems:
        print(f"[ERROR] {p}", file=sys.stderr)
    if problems:
        sys.exit(1)

    left = audit_voice(rows)
    for l in left:
        print(f"[ERROR] còn ngôi 'tôi' ở câu hỏi — {l}", file=sys.stderr)
    if left:
        sys.exit(1)

    if not args.check:
        path.write_text(
            json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    print(f"[OK] {path}", file=sys.stderr)
    print(f"     vừa sửa  : {applied}", file=sys.stderr)
    print(f"     đã đúng  : {already}", file=sys.stderr)
    print(f"     tổng     : {len(ALL_FIXES)} sửa đổi "
          f"({len(LOGIC_FIXES)} lệch logic §1.4, "
          f"{len(VOICE_FIXES)} đổi ngôi §1.3)", file=sys.stderr)


if __name__ == "__main__":
    main()
