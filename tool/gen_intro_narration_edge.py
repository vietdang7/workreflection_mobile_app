#!/usr/bin/env python3
import asyncio
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
import edge_tts
from gtts import gTTS

VOICE = "vi-VN-HoaiMyNeural"
GAP_SECONDS = 0.6

SCENES = [
    {
        "id": "welcome",
        "text": "Chào bạn, đây là WorkReflection. Mỗi ngày, bạn chỉ cần một hai phút để nhìn lại công việc của mình.",
        "spoken": "Chào bạn, đây là quậc rì léc sần. Mỗi ngày, bạn chỉ cần một hai phút để nhìn lại công việc của mình.",
    },
    {
        "id": "reflect",
        "text": "Ở tab Hôm nay, bạn chạm chọn cảm xúc lúc này. Rồi bạn nhìn lại một khoảnh khắc qua bốn bước: chọn tình huống, đọc một câu chuyện, xem một góc nhìn khác, và chọn bước tiếp theo.",
        "spoken": "Ở tab Hôm nay, bạn chạm chọn cảm xúc lúc này. Rồi bạn nhìn lại một khoảnh khắc qua bốn bước: chọn tình huống, đọc một câu chuyện, xem một góc nhìn khác, và chọn bước tiếp theo.",
    },
    {
        "id": "understand",
        "text": "Qua nhiều lần nhìn lại, tab Hiểu mình chỉ ra những vòng lặp quen thuộc, những điều cứ quay lại với bạn trong công việc.",
        "spoken": "Qua nhiều lần nhìn lại, tab Hiểu mình chỉ ra những vòng lặp quen thuộc, những điều cứ quay lại với bạn trong công việc.",
    },
    {
        "id": "grow",
        "text": "Ở tab Phát triển, ứng dụng tự gợi ý chủ đề thực hành hợp với bạn. Mỗi lần thực hành, bạn đánh dấu một lần. Giữ đều đặn, điều đó thành kỹ năng của bạn.",
        "spoken": "Ở tab Phát triển, ứng dụng tự gợi ý chủ đề thực hành hợp với bạn. Mỗi lần thực hành, bạn đánh dấu một lần. Giữ đều đặn, điều đó thành kỹ năng của bạn.",
    },
    {
        "id": "assistant",
        "text": "Cần hỏi gì, bạn chạm biểu tượng trò chuyện ở góc dưới bên phải để mở Trợ lý AI. Trợ lý đọc các ghi nhận của bạn, nên trả lời sát với bối cảnh của bạn.",
        "spoken": "Cần hỏi gì, bạn chạm biểu tượng trò chuyện ở góc dưới bên phải để mở Trợ lý ây ai. Trợ lý đọc các ghi nhận của bạn, nên trả lời sát với bối cảnh của bạn.",
    },
    {
        "id": "closing",
        "text": "Mọi lần nhìn lại đều được lưu ở tab Hành trình. Bắt đầu bằng một lần chạm ở tab Hôm nay nhé.",
        "spoken": "Mọi lần nhìn lại đều được lưu ở tab Hành trình. Bắt đầu bằng một lần chạm ở tab Hôm nay nhé.",
    },
]

def get_duration_ms(path: str) -> int:
    cmd = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        path,
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return round(float(res.stdout.strip()) * 1000)

async def generate_scene_audio(text: str, voice: str, out_file: Path, max_retries: int = 4):
    for attempt in range(max_retries):
        try:
            communicate = edge_tts.Communicate(text, voice)
            await communicate.save(str(out_file))
            if out_file.exists() and out_file.stat().st_size > 500:
                return "edge_tts"
        except Exception as e:
            print(f"      (Thử lại lần {attempt + 1}/{max_retries}: {e})")
            await asyncio.sleep(2.0 * (attempt + 1))
    
    print("      (Chuyển sang fallback gTTS...)")
    tts = gTTS(text=text, lang="vi")
    tts.save(str(out_file))
    return "gtts"

async def main():
    repo_root = Path(__file__).resolve().parent.parent
    out_dir = repo_root / "assets" / "intro"
    out_dir.mkdir(parents=True, exist_ok=True)
    temp_dir = repo_root / ".temp_intro_audio"
    temp_dir.mkdir(parents=True, exist_ok=True)

    print(f"Bắt đầu sinh voice liền mạch 100% giọng Hoài My: {VOICE}...")
    padded_wavs = []
    durations_ms = []

    for i in range(len(SCENES)):
        scene = SCENES[i]
        print(f"[{i+1}/6] Đang sinh giọng cho cảnh '{scene['id']}'...")
        raw_mp3 = temp_dir / f"scene_{i}.mp3"
        spoken = scene.get("spoken", scene["text"])
        engine = await generate_scene_audio(spoken, VOICE, raw_mp3)

        wav_path = temp_dir / f"scene_{i}.wav"
        is_last = (i == len(SCENES) - 1)
        ffmpeg_cmd = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", str(raw_mp3),
            "-ac", "1",
            "-ar", "24000",
        ]
        if not is_last:
            ffmpeg_cmd.extend(["-af", f"apad=pad_dur={GAP_SECONDS}"])
        ffmpeg_cmd.append(str(wav_path))
        subprocess.run(ffmpeg_cmd, check=True)

        dur_ms = get_duration_ms(str(wav_path))
        durations_ms.append(dur_ms)
        padded_wavs.append(wav_path)
        print(f"      -> Thành công ({engine}): {dur_ms} ms")
        await asyncio.sleep(1.0)

    # Tạo file danh sách nối
    list_file = temp_dir / "list.txt"
    list_content = "\n".join([f"file '{p.resolve()}'" for p in padded_wavs])
    list_file.write_text(list_content, encoding="utf-8")

    out_mp3 = out_dir / "intro_vi.mp3"
    print(f"Đang ghép các cảnh vào {out_mp3}...")
    concat_cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "concat", "-safe", "0",
        "-i", str(list_file),
        "-ac", "1",
        "-b:a", "64k",
        str(out_mp3),
    ]
    subprocess.run(concat_cmd, check=True)
    total_ms = get_duration_ms(str(out_mp3))
    print(f"Tổng thời lượng file MP3: {total_ms} ms ({total_ms / 1000:.2f}s)")

    timed_scenes = []
    start = 0
    for i, scene in enumerate(SCENES):
        is_last = (i == len(SCENES) - 1)
        end = total_ms if is_last else start + durations_ms[i]
        timed_scenes.append({
            "id": scene["id"],
            "text": scene["text"],
            "startMs": start,
            "endMs": end,
        })
        start = end

    metadata = {
        "lang": "vi",
        "voice": VOICE,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "audio": "assets/intro/intro_vi.mp3",
        "durationMs": total_ms,
        "scenes": timed_scenes,
    }

    out_json = out_dir / "intro_vi.json"
    out_json.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Đã lưu metadata vào {out_json}")

    # Copy ngay sang build/flutter_assets để web nhận ngay không bị lệch cache
    build_assets = repo_root / "build" / "flutter_assets" / "assets" / "intro"
    if build_assets.exists():
        import shutil
        shutil.copy(str(out_mp3), str(build_assets / "intro_vi.mp3"))
        shutil.copy(str(out_json), str(build_assets / "intro_vi.json"))
        print(f"Đã đồng bộ sang {build_assets}")

    # Dọn dẹp thư mục tạm
    for f in temp_dir.glob("*"):
        f.unlink()
    temp_dir.rmdir()
    print("Hoàn tất thành công!")

if __name__ == "__main__":
    asyncio.run(main())
