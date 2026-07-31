"""Generate the AnimaStudio ribbon icon set.

Crisp geometric line-art (Fusion-style), drawn with Pillow at 4× and
downsampled to 64×64 PNGs in Assets/AnimaStudio/Resources/Icons/ so the
player loads them via Resources.Load. Re-run after editing; output is
deterministic.

Usage: .venv/bin/python unity/Tools/gen_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / (
    "AnimaStudioUnity/Assets/AnimaStudio/Resources/Icons"
)
S = 256          # supersampled canvas
FINAL = 64
LINE = (58, 64, 74, 255)        # dark slate strokes
ACCENT = (53, 119, 241, 255)    # AnimaStudio blue
RED = (214, 69, 65, 255)
W = 14           # stroke width at 4x


def canvas():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img: Image.Image, name: str):
    OUT.mkdir(parents=True, exist_ok=True)
    img.resize((FINAL, FINAL), Image.LANCZOS).save(OUT / f"{name}.png")


def rounded(draw, box, **kw):
    draw.rounded_rectangle(box, radius=18, **kw)


def arrow_head(draw, tip, direction, size=34, fill=LINE):
    x, y = tip
    dx, dy = direction
    px, py = -dy, dx
    draw.polygon(
        [(x, y),
         (x - dx * size + px * size * 0.7, y - dy * size + py * size * 0.7),
         (x - dx * size - px * size * 0.7, y - dy * size - py * size * 0.7)],
        fill=fill)


def icon_import():
    img, d = canvas()
    d.line([(128, 30), (128, 150)], fill=ACCENT, width=W)
    arrow_head(d, (128, 168), (0, 1), fill=ACCENT)
    d.line([(48, 140), (48, 210), (208, 210), (208, 140)], fill=LINE, width=W,
           joint="curve")
    save(img, "import")


def icon_rescan():
    img, d = canvas()
    d.arc([48, 48, 208, 208], start=-40, end=200, fill=LINE, width=W)
    arrow_head(d, (196, 74), (0.75, -0.66))
    d.arc([48, 48, 208, 208], start=140, end=340, fill=LINE, width=W)
    arrow_head(d, (60, 182), (-0.75, 0.66))
    save(img, "rescan")


def cube(d, cx, cy, r, outline=LINE):
    top = [(cx, cy - r), (cx + r, cy - r * 0.45), (cx, cy + r * 0.1),
           (cx - r, cy - r * 0.45)]
    d.polygon(top, outline=outline, width=W)
    d.line([(cx - r, cy - r * 0.45), (cx - r, cy + r * 0.55),
            (cx, cy + r * 1.1), (cx + r, cy + r * 0.55),
            (cx + r, cy - r * 0.45)], fill=outline, width=W, joint="curve")
    d.line([(cx, cy + r * 0.1), (cx, cy + r * 1.1)], fill=outline, width=W)


def icon_assembly_new():
    img, d = canvas()
    cube(d, 110, 118, 78)
    d.line([(196, 168), (196, 232)], fill=ACCENT, width=W + 4)
    d.line([(164, 200), (228, 200)], fill=ACCENT, width=W + 4)
    save(img, "assembly_new")


def icon_save():
    img, d = canvas()
    rounded(d, [40, 40, 216, 216], outline=LINE, width=W)
    d.rectangle([88, 40, 176, 104], outline=LINE, width=W)
    d.rectangle([76, 140, 180, 216], outline=LINE, width=W)
    save(img, "save")


def icon_fastened():
    img, d = canvas()
    rounded(d, [36, 84, 124, 172], outline=LINE, width=W)
    rounded(d, [132, 84, 220, 172], outline=LINE, width=W)
    d.line([(108, 128), (148, 128)], fill=ACCENT, width=W + 6)
    save(img, "fastened")


def icon_parallel():
    img, d = canvas()
    d.polygon([(60, 60), (140, 40), (140, 160), (60, 180)], outline=LINE, width=W)
    d.polygon([(116, 96), (196, 76), (196, 196), (116, 216)], outline=ACCENT,
              width=W)
    save(img, "parallel")


def icon_revolute():
    img, d = canvas()
    d.ellipse([64, 64, 192, 192], outline=LINE, width=W)
    d.ellipse([116, 116, 140, 140], fill=ACCENT)
    d.arc([28, 28, 228, 228], start=-70, end=30, fill=ACCENT, width=W)
    arrow_head(d, (212, 74), (0.35, -0.93), fill=ACCENT)
    save(img, "revolute")


def icon_slider():
    img, d = canvas()
    rounded(d, [32, 104, 224, 152], outline=LINE, width=W)
    d.line([(76, 128), (180, 128)], fill=ACCENT, width=W)
    arrow_head(d, (196, 128), (1, 0), fill=ACCENT)
    arrow_head(d, (60, 128), (-1, 0), fill=ACCENT)
    save(img, "slider")
    save(img, "prismatic")  # the engine's type string for Slider


def icon_cylindrical():
    img, d = canvas()
    d.ellipse([68, 40, 188, 92], outline=LINE, width=W)
    d.line([(68, 66), (68, 190)], fill=LINE, width=W)
    d.line([(188, 66), (188, 190)], fill=LINE, width=W)
    d.arc([68, 164, 188, 216], start=0, end=180, fill=LINE, width=W)
    d.arc([88, 100, 168, 150], start=-60, end=140, fill=ACCENT, width=W)
    save(img, "cylindrical")


def icon_pin_slot():
    img, d = canvas()
    rounded(d, [36, 92, 220, 164], outline=LINE, width=W)
    d.ellipse([76, 108, 116, 148], fill=ACCENT)
    d.line([(126, 128), (186, 128)], fill=LINE, width=W)
    arrow_head(d, (196, 128), (1, 0))
    save(img, "pin_slot")


def icon_planar():
    img, d = canvas()
    d.polygon([(52, 168), (128, 120), (204, 168), (128, 216)], outline=LINE,
              width=W)
    d.line([(128, 96), (128, 44)], fill=ACCENT, width=W)
    arrow_head(d, (128, 34), (0, -1), fill=ACCENT)
    save(img, "planar")


def icon_ball():
    img, d = canvas()
    d.arc([48, 96, 208, 256], start=180, end=360, fill=LINE, width=W)
    d.ellipse([92, 68, 164, 140], outline=ACCENT, width=W)
    d.ellipse([120, 96, 136, 112], fill=ACCENT)
    save(img, "ball")


def icon_remove_part():
    img, d = canvas()
    cube(d, 112, 112, 72)
    d.line([(160, 160), (224, 224)], fill=RED, width=W + 4)
    d.line([(224, 160), (160, 224)], fill=RED, width=W + 4)
    save(img, "remove_part")


def icon_remove_mate():
    img, d = canvas()
    rounded(d, [36, 96, 128, 160], outline=LINE, width=W)
    rounded(d, [116, 96, 208, 160], outline=LINE, width=W)
    d.line([(150, 170), (214, 234)], fill=RED, width=W + 4)
    d.line([(214, 170), (150, 234)], fill=RED, width=W + 4)
    save(img, "remove_mate")


def icon_reset():
    img, d = canvas()
    d.arc([56, 56, 200, 200], start=-240, end=30, fill=LINE, width=W)
    arrow_head(d, (78, 76), (-0.6, -0.8))
    save(img, "reset")


ALL = [icon_import, icon_rescan, icon_assembly_new, icon_save, icon_fastened,
       icon_parallel, icon_revolute, icon_slider, icon_cylindrical,
       icon_pin_slot, icon_planar, icon_ball, icon_remove_part,
       icon_remove_mate, icon_reset]

if __name__ == "__main__":
    for fn in ALL:
        fn()
    print(f"wrote {len(ALL)} icons → {OUT}")
