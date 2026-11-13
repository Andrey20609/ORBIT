from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055"
MEDIA = OUT / "screenshots"


def main() -> None:
    records = []
    pngs = sorted(MEDIA.glob("*.png"))
    videos = sorted(MEDIA.glob("*.mp4"))
    assert len(pngs) == 63, f"Expected 63 accepted PNG, got {len(pngs)}"
    assert len(videos) == 5, f"Expected 5 accepted MP4, got {len(videos)}"
    for path in pngs:
        with Image.open(path) as source:
            source.load()
            image = source.convert("RGBA").resize((96, 96))
            pixels = list(zip(*[iter(image.tobytes())] * 4))
            opaque = sum(pixel[3] > 0 for pixel in pixels) / len(pixels)
            bins = len({(pixel[0] >> 4, pixel[1] >> 4, pixel[2] >> 4) for pixel in pixels})
            variance = ImageStat.Stat(image.convert("L")).var[0]
            assert source.width == 1080 and source.height == 2400, path
        assert opaque >= 0.999 and bins >= 2 and variance > 0, (path, opaque, bins, variance)
        records.append(
            {
                "file": path.name,
                "bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "width": 1080,
                "height": 2400,
                "opaqueFraction": opaque,
                "colorBins": bins,
                "lumaVariance": variance,
                "status": "PASS",
            }
        )
    video_records = []
    for path in videos:
        data = path.read_bytes()
        assert len(data) > 100_000 and data[4:8] == b"ftyp" and b"mdat" in data, path
        video_records.append(
            {
                "file": path.name,
                "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
                "status": "CONTAINER_PRESENT; screenrecord source log retained; playback NOT RUN",
            }
        )
    result = {
        "status": "PASS",
        "pngCount": len(records),
        "pngPixelValidation": "63/63 PASS",
        "mp4Count": len(video_records),
        "mp4Playback": "NOT RUN; ffprobe unavailable",
        "png": records,
        "mp4": video_records,
    }
    (OUT / "runtime" / "media-validation.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    lines = [
        f"PNG {record['file']}: PASS; sha256={record['sha256']}; bins={record['colorBins']}"
        for record in records
    ] + [f"MP4 {record['file']}: {record['status']}" for record in video_records]
    (OUT / "logs" / "media-validation.txt").write_text(
        "63/63 PNG pixel validation PASS\n" + "\n".join(lines) + "\n", encoding="utf-8"
    )
    print("63/63 PNG pixel validation PASS; 5 MP4 containers present; playback NOT RUN")


if __name__ == "__main__":
    main()
