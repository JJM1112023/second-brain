"""Generate PWA icons for the Awesome Ninja Admins Codex."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "icons"
OUT.mkdir(parents=True, exist_ok=True)


def bg_gradient(size, center=(0x04, 0x06, 0x0b), edge=(0x00, 0x00, 0x00)):
    img = Image.new("RGB", (size, size), edge)
    px = img.load()
    cx, cy = size / 2, size / 2
    maxd = (cx**2 + cy**2) ** 0.5
    for y in range(size):
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / maxd
            t = min(1.0, d * 1.15)
            r = int(center[0] * (1 - t) + edge[0] * t)
            g = int(center[1] * (1 - t) + edge[1] * t)
            b = int(center[2] * (1 - t) + edge[2] * t)
            px[x, y] = (r, g, b)
    return img


def draw_ninja_glyph(img, safe_ratio=1.0):
    """Draw a stylized shuriken/ninja mark. safe_ratio<1 shrinks for maskable."""
    size = img.width
    d = ImageDraw.Draw(img, "RGBA")
    cx = cy = size / 2
    R = size * 0.36 * safe_ratio  # outer radius
    r = size * 0.09 * safe_ratio  # inner hub

    # Glow halo
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse(
        [cx - R * 1.25, cy - R * 1.25, cx + R * 1.25, cy + R * 1.25],
        fill=(0x7c, 0x5c, 0xff, 90),
    )
    halo = halo.filter(ImageFilter.GaussianBlur(size * 0.05))
    img.alpha_composite(halo)

    # 4-point shuriken (two overlapping diamonds with slight rotation)
    import math

    def diamond(angle_deg, color, scale=1.0):
        a = math.radians(angle_deg)
        pts = []
        for pa in (0, 90, 180, 270):
            theta = math.radians(pa) + a
            reach = R * scale if pa % 180 == 0 else R * 0.28 * scale
            pts.append((cx + math.cos(theta) * reach, cy + math.sin(theta) * reach))
        d.polygon(pts, fill=color)

    diamond(0, (0x00, 0xff, 0xc6, 235))       # cyan
    diamond(45, (0x7c, 0x5c, 0xff, 220))      # violet

    # Center hub ring
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0x04, 0x06, 0x0b, 255))
    d.ellipse(
        [cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55],
        fill=(0x00, 0xff, 0xc6, 255),
    )

    # Subtle stroke outline on diamonds via redraw with alpha
    for angle, color in ((0, (255, 255, 255, 40)), (45, (255, 255, 255, 30))):
        a = math.radians(angle)
        pts = []
        for pa in (0, 90, 180, 270):
            theta = math.radians(pa) + a
            reach = R if pa % 180 == 0 else R * 0.28
            pts.append((cx + math.cos(theta) * reach, cy + math.sin(theta) * reach))
        d.line(pts + [pts[0]], fill=color, width=max(2, size // 200))


def make_icon(size, path, maskable=False):
    base = bg_gradient(size).convert("RGBA")
    if maskable:
        # Maskable spec: keep art inside inner 80% safe zone
        draw_ninja_glyph(base, safe_ratio=0.78)
    else:
        draw_ninja_glyph(base, safe_ratio=1.0)
    base.convert("RGB").save(path, "PNG", optimize=True)
    print(f"wrote {path} ({size}x{size})")


if __name__ == "__main__":
    make_icon(192, OUT / "icon-192.png")
    make_icon(512, OUT / "icon-512.png")
    make_icon(512, OUT / "maskable-512.png", maskable=True)
    # Favicon (also useful)
    make_icon(64, OUT / "favicon-64.png")
