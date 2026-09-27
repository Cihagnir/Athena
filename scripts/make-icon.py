#!/usr/bin/env python3
"""Uygulama simgesini üretir → macos/TaskTracker/Resources/AppIcon.icns

E-ink dili: kâğıt zemin, mürekkep çerçeve, ortada dolu ▸ (menü çubuğundaki "▸ 3/7"
işaretiyle aynı). Renk yok. Üretilen .icns repoya girer; bu betik yalnızca
simgeyi değiştirmek için gerekir (Pillow: pip install pillow).
"""
import os
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw

PAPER = (0xF2, 0xF0, 0xEA)
INK = (0x11, 0x11, 0x11)
OUT = os.path.join(os.path.dirname(__file__), "..", "macos", "TaskTracker", "Resources", "AppIcon.icns")


def draw(size: int) -> Image.Image:
    # 4x süperörnekleme: kenarlar yumuşak olsun
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # macOS simge ızgarası: içerik kenarlardan ~%10 içeride, köşe yarıçapı ~%22
    m = s * 0.10
    r = s * 0.22
    d.rounded_rectangle([m, m, s - m, s - m], radius=r, fill=PAPER)
    stroke = max(s * 0.035, 4)
    d.rounded_rectangle([m, m, s - m, s - m], radius=r, outline=INK, width=int(stroke))
    # ▸ : eşkenar üçgen, kütle merkezi tam ortada
    cx, cy = s / 2, s / 2
    h = s * 0.30            # yükseklik (üst-alt)
    w = h * 0.92            # genişlik
    tri = [(cx - w / 2 + w * 0.08, cy - h / 2), (cx - w / 2 + w * 0.08, cy + h / 2), (cx + w / 2 + w * 0.08, cy)]
    d.polygon(tri, fill=INK)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    tmp = tempfile.mkdtemp()
    iconset = os.path.join(tmp, "AppIcon.iconset")
    os.mkdir(iconset)
    for base in (16, 32, 128, 256, 512):
        draw(base).save(os.path.join(iconset, f"icon_{base}x{base}.png"))
        draw(base * 2).save(os.path.join(iconset, f"icon_{base}x{base}@2x.png"))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", OUT], check=True)
    # önizleme için 256'lık PNG de bırak
    draw(256).save(os.path.join(tmp, "preview.png"))
    print("yazıldı:", os.path.normpath(OUT))
    print("önizleme:", os.path.join(tmp, "preview.png"))
    shutil.rmtree(iconset)


if __name__ == "__main__":
    main()
