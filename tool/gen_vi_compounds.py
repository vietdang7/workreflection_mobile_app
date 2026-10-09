#!/usr/bin/env python3
"""Sinh `lib/core/l10n/wr_vi_compounds.g.dart` — danh sách từ ghép hai tiếng.

Khách (họp 08/10): chữ không được rớt giữa một từ ghép, ví dụ "phụ thuộc" bị
tách thành "phụ / thuộc". Tiếng Việt viết rời từng tiếng nên Flutter không biết
đâu là một từ; cần một danh sách.

Nguồn: từ điển Viet74K (https://github.com/duyet/vietnamese-wordlist,
`Viet74K.txt`). Lấy cả từ điển thì gần 50.000 từ hai tiếng — quá nặng để nhúng
vào app. Nên chỉ giữ những từ THỰC SỰ xuất hiện trong chữ của app: chuỗi trong
`lib/`, nội dung seed trong `supabase/migrations/`, và `scripts/`.

Chạy lại sau khi thêm nhiều câu chữ mới:

    curl -sSL -o /tmp/Viet74K.txt \
      https://raw.githubusercontent.com/duyet/vietnamese-wordlist/master/Viet74K.txt
    python3 tool/gen_vi_compounds.py /tmp/Viet74K.txt
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'lib/core/l10n/wr_vi_compounds.g.dart'

# Cặp từ điển có nhưng ghép vào thì sai nghĩa trong câu của app, hoặc là hai
# hư từ đi cạnh nhau rất thường mà không phải một từ ("của bạn" nằm trong
# Viet74K? không, nhưng lỡ có thì cũng loại).
EXCLUDE = {
    'của bạn',
    'bạn có',
    'có thể',  # để "có thể" co giãn được ở dòng hẹp — rất dày trong câu.
}

# Chỉ chữ cái (kể cả có dấu). Một "tiếng" là một dãy chữ cái liền nhau.
WORD = re.compile(r"[^\W\d_]+", re.UNICODE)


def load_dictionary(path: str) -> set[str]:
    words = set()
    for line in pathlib.Path(path).read_text(encoding='utf-8').splitlines():
        parts = line.strip().lower().split()
        if len(parts) == 2 and all(WORD.fullmatch(p) for p in parts):
            words.add(' '.join(parts))
    return words


def corpus_files():
    yield from (ROOT / 'lib').rglob('*.dart')
    yield from (ROOT / 'supabase/migrations').glob('*.sql')
    yield from (ROOT / 'scripts').glob('*')


def corpus_text() -> str:
    chunks = []
    for f in corpus_files():
        if f == OUT or not f.is_file():
            continue
        for line in f.read_text(encoding='utf-8', errors='ignore').splitlines():
            if line.lstrip().startswith(('//', '--', '#')):
                continue  # chú thích, không phải chữ người dùng đọc
            chunks.append(line)
    return '\n'.join(chunks)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    dictionary = load_dictionary(sys.argv[1])
    found = set()
    # Hai tiếng liền nhau, cách đúng một dấu cách — giống điều kiện lúc chạy.
    for line in corpus_text().lower().splitlines():
        tokens = [(m.group(), m.start(), m.end()) for m in WORD.finditer(line)]
        for (a, _, ea), (b, sb, _) in zip(tokens, tokens[1:]):
            if line[ea:sb] == ' ':
                pair = f'{a} {b}'
                if pair in dictionary and pair not in EXCLUDE:
                    found.add(pair)

    body = '\n'.join(f"  '{w}'," for w in sorted(found))
    OUT.write_text(
        '// GENERATED — đừng sửa tay. Sinh bởi `tool/gen_vi_compounds.py`.\n'
        '//\n'
        '// Từ ghép hai tiếng (Viet74K) có xuất hiện trong chữ của app. Dùng ở\n'
        '// `wrKeepCompoundsTogether` để từ ghép không bị ngắt dòng ở giữa.\n'
        '\n'
        f'const Set<String> kWrViCompounds = {{\n{body}\n}};\n',
        encoding='utf-8',
    )
    print(f'{len(found)} từ ghép → {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
