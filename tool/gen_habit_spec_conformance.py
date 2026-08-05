#!/usr/bin/env python3
"""Sinh test đối chiếu mã nguồn với bảng B.2 và B.3 của tài liệu Ma trận Cấp bậc.

Vì sao cần: cả hai bảng đều là nội dung chép tay từ .docx vào Dart. Chép tay thì
sai được, mà sai một chữ trong 60 ô thì không ai đọc ra bằng mắt. Script này đọc
thẳng .docx và sinh ra test khẳng định từng ô — test sai là biết ngay chép lệch,
chứ không phải "khớp với những gì người viết mã nhớ về tài liệu".

Dùng:
    python3 tool/gen_habit_spec_conformance.py \\
        "/home/duythong/Desktop/FileTam/workreflection/WorkReflection-Thoi-quen-va-Ma-tran-Cap-bac-v1.0.docx"
    flutter test test/core/logic/wr_habit_spec_conformance_test.dart

Tài liệu nằm NGOÀI repo (thư mục FileTam), nên không nhúng đường dẫn mặc định
tuyệt đối vào CI — chạy tay mỗi khi tài liệu ra bản mới.

Phần A.2 (mô tả mở đầu + câu đạt ngưỡng) KHÔNG sinh test ở đây: nội dung đó nằm
trong DB, không nằm trong mã. Đối chiếu nó bằng cách dump bảng
`wr_practice_themes` rồi so với `--check-dump`.
"""

import argparse
import html
import json
import re
import sys
import zipfile

TIERS = ["individual", "leadTeam", "leadOrg"]

DIM = {f"{p}{i}": f"{p.lower()}{i}" for p, n in (("S", 3), ("C", 3), ("A", 4))
       for i in range(1, n + 1)}

REL = {
    "Cần": "needed",
    "Nên có": "nice",
    "Cần, ưu tiên cao": "critical",
}

# Tên chủ đề trong tài liệu → theme_id trong DB. Tài liệu viết bằng tên hiển
# thị; mã nguồn khoá theo theme_id (xem Phần C mục 1 — không bao giờ theo tên).
TITLE2ID = {
    "Rõ ràng về điều được kỳ vọng": "pt-s1",
    "Ưu tiên đúng việc của mình": "pt-s2",
    "Vững vàng khi mọi thứ thay đổi": "pt-s3",
    "Tin và được tin": "pt-c1",
    "Dám lên tiếng": "pt-c2",
    "Phản hồi thật, không chỉ lịch sự": "pt-c3",
    "Nhìn rõ mình đang đi đâu": "pt-a1",
    "Giữ năng lượng đường dài": "pt-a2",
    "Thoát khỏi vòng lặp phản ứng": "pt-a3",
    "Không lặp lại cùng một bài học": "pt-a4",
}


def docx_lines(path):
    """Văn bản của .docx, mỗi đoạn/ô một dòng, ô ngăn bằng ' | '."""
    xml = zipfile.ZipFile(path).read("word/document.xml").decode("utf8")
    xml = re.sub(r"</w:p>", "\n", xml)
    xml = re.sub(r"</w:tc>", " | ", xml)
    xml = re.sub(r"</w:tr>", "\n", xml)
    return [l.rstrip() for l in html.unescape(re.sub(r"<[^>]+>", "", xml)).split("\n")]


def cells_between(lines, start, end):
    i = lines.index(start)
    j = lines.index(end)
    out = []
    for line in lines[i:j]:
        s = line.strip()
        if not s or s == "|":
            continue
        if s.endswith("|"):
            s = s[:-1].strip()
        if s.startswith("|"):
            s = s[1:].strip()
        if s:
            out.append(s)
    return out


def parse(path):
    lines = docx_lines(path)

    b2 = cells_between(
        lines,
        "B.2 Bảng mức độ liên quan, dùng để xếp hạng khoảng trống",
        "B.3 Nội dung bước Chuyển hóa viết lại theo ba cấp bậc",
    )
    b2 = b2[b2.index("Chiều") + 4:]
    b2 = [b2[k:k + 4] for k in range(0, len(b2), 4)]

    b3 = cells_between(
        lines,
        "B.3 Nội dung bước Chuyển hóa viết lại theo ba cấp bậc",
        "Phần C. Việc cần cập nhật, viết riêng cho dev",
    )
    b3 = b3[b3.index("Chủ đề") + 4:]
    b3 = [b3[k:k + 4] for k in range(0, len(b3), 4)]

    a2 = cells_between(
        lines,
        "A.2 Mười mô tả đầy đủ",
        "Phần B. Ma trận cấp bậc cho đối chiếu JD",
    )
    a2 = a2[a2.index("Chủ đề") + 3:]
    a2 = [a2[k:k + 3] for k in range(0, len(a2), 3)]
    a2 = [r for r in a2 if len(r) == 3 and not r[0].startswith("Giọng chung")]

    for name, rows, width in (("B.2", b2, 4), ("B.3", b3, 4), ("A.2", a2, 3)):
        if len(rows) != 10 or any(len(r) != width for r in rows):
            sys.exit(f"Bảng {name} đọc ra {len(rows)} dòng — tài liệu đã đổi cấu "
                     f"trúc, sửa script trước khi tin kết quả.")
    return b2, b3, a2


def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def generate(b2, b3, out_path, docx_name):
    L = [
        f"// SINH TỰ ĐỘNG từ {docx_name}",
        "// (script: tool/gen_habit_spec_conformance.py). ĐỪNG sửa tay — sửa tài",
        "// liệu rồi chạy lại script.",
        "//",
        "// Mục đích: chứng minh mã nguồn khớp NGUYÊN VĂN hai bảng của tài liệu,",
        "// chứ không chỉ khớp với những gì người viết mã nhớ về tài liệu.",
        "//",
        "// Run: flutter test test/core/logic/wr_habit_spec_conformance_test.dart",
        "",
        "import 'package:flutter_test/flutter_test.dart';",
        "import 'package:workreflection_mobile/core/logic/wr_seniority.dart';",
        "import 'package:workreflection_mobile/core/models/wr_content.dart';",
        "",
        "void main() {",
        "  group('B.2 — 30 ô của bảng mức độ liên quan', () {",
    ]
    for row in b2:
        code = re.search(r"\((S\d|C\d|A\d)\)", row[0]).group(1)
        for k, tier in enumerate(TIERS):
            L += [
                f"    test('{code} × {tier} = {row[k + 1]}', () {{",
                f"      expect(relevanceOf(ScaDimension.{DIM[code]}, SeniorityTier.{tier}),",
                f"          SkillRelevance.{REL[row[k + 1]]});",
                "    });",
            ]
    L += ["  });", "", "  group('B.3 — 30 ô nội dung bước Chuyển hoá', () {"]
    for row in b3:
        tid = TITLE2ID[row[0]]
        for k, tier in enumerate(TIERS):
            L += [
                f"    test('{tid} × {tier}', () {{",
                f"      expect(transformContentFor({dart_str(tid)}, SeniorityTier.{tier}),",
                f"          {dart_str(row[k + 1])});",
                "    });",
            ]
    L += ["  });", "}"]
    open(out_path, "w", encoding="utf8").write("\n".join(L) + "\n")
    print(f"Đã sinh {sum(1 for l in L if l.startswith('    test('))} test → {out_path}")


def check_dump(a2, dump_path):
    """So nội dung A.2 với dump thật của bảng wr_practice_themes."""
    t = open(dump_path, encoding="utf8").read()
    i = t.find('INSERT INTO "public"."wr_practice_themes"')
    if i < 0:
        sys.exit("Dump không có bảng wr_practice_themes.")
    seg = t[i:t.find("\n\n\n", i)]
    db = {}
    row_re = (r"\('(pt-[a-z0-9]+)', '((?:[^']|'')*)', '(?:[^']|'')*', "
              r"'((?:[^']|'')*)', '[^']*', (?:NULL|'[^']*'), (NULL|'(?:[^']|'')*')\)")
    for m in re.finditer(row_re, seg):
        fl = None if m.group(4) == "NULL" else m.group(4)[1:-1].replace("''", "'")
        db[m.group(1)] = (m.group(2).replace("''", "'"),
                          m.group(3).replace("''", "'"), fl)

    bad = 0
    for title, desc, line in a2:
        tid = TITLE2ID[title]
        if tid not in db:
            print(f"✗ {tid}: không có trong dump")
            bad += 1
            continue
        dbt, dbd, dbf = db[tid]
        for what, want, got in (("TÊN", title, dbt),
                                ("MÔ TẢ", desc, dbd),
                                ("CÂU NGƯỠNG", line, dbf)):
            if want != got:
                print(f"✗ {tid} {what} lệch:\n  file: {want}\n  db  : {got}")
                bad += 1
    print(f"A.2 — 10 chủ đề × 3 trường = 30 ô. Lệch: {bad}")
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("docx")
    ap.add_argument("--out",
                    default="test/core/logic/wr_habit_spec_conformance_test.dart")
    ap.add_argument("--check-dump",
                    help="Đường dẫn file dump (supabase db dump --data-only) "
                         "để đối chiếu thêm phần A.2 nằm trong DB.")
    args = ap.parse_args()

    b2, b3, a2 = parse(args.docx)
    generate(b2, b3, args.out, args.docx.rsplit("/", 1)[-1])
    if args.check_dump:
        sys.exit(1 if check_dump(a2, args.check_dump) else 0)


if __name__ == "__main__":
    main()
